import Cocoa
import Foundation
import Darwin
import ApplicationServices
import KlawosContracts

@MainActor final class AgentEngine {
    let resources:URL
    var busy=false;let helper=HelperRuntime()
    let settingsSync:CloudSettingsSync?
    var syncMessage="Checking iCloud…"
    private let syncWaitingMessage="Waiting for iCloud to download your settings. Sync will retry automatically."
    var knownIdentity:DeviceIdentity?
    var studioRequested=false
    private var loginResumePending=false
    init(resources:URL){
        self.resources=resources
        loginResumePending=HelperStartupPolicy.shouldResume(startAtLogin:helper.preferences.startAtLogin,
            wasRunning:helper.preferences.wasRunning,configured:!(helper.saved?.allocations.isEmpty ?? true))
        let cloud=FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs",isDirectory:true)
        settingsSync=try? CloudSettingsSync(cloudRoot:cloud,localRoot:AgentPaths.directory)
    }
    private func localSettings()->SharedSettings {
        SharedSettings(profiles:helper.saved?.configuration.bindings ?? [:],
                       layerNames:settingsSync?.pendingSettings?.layerNames ?? settingsSync?.localSettings?.layerNames ?? [])
    }
    private func currentNames()->[String] {
        let file=AgentPaths.directory.appendingPathComponent("draft.json")
        guard let data=try? Data(contentsOf:file),
              let draft=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let project=draft["projectDocument"] as? [String:Any],
              let metadata=project["metadata"] as? [String:Any],
              let names=metadata["layerNames"] as? [String] else{return settingsSync?.localSettings?.layerNames ?? []}
        return names
    }
    private func matchingAllocations(_ profiles:[InputID:ContextBindings],snapshot:Snapshot)throws->[InputID:String]? {
        let inputs=Array(profiles.keys)
        let plan=try TriggerAllocator().allocate(snapshot:snapshot,helperInputs:inputs)
        guard plan.fieldEdits.count==inputs.count,
              plan.allocations.allSatisfy({ input,code in
                  let parts=input.split(separator:":")
                  guard parts.count==3,let row=Int(parts[1]),let column=Int(parts[2]),
                        case .array(let layers)=snapshot.hardware["layout"],
                        case .array(let rows)=layers.first,rows.indices.contains(row),
                        case .array(let keys)=rows[row],keys.indices.contains(column) else{return false}
                  return keys[column] == .string(code)
              }) else{return nil}
        return plan.allocations
    }
    private func draftHasChanges()->Bool {
        let file=AgentPaths.directory.appendingPathComponent("draft.json")
        guard let data=try? Data(contentsOf:file),
              let draft=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let base=draft["base"] as? [String:Any] else{return false}
        func equal(_ first:Any?,_ second:Any?)->Bool {
            guard let first,let second,
                  let a=try? JSONSerialization.data(withJSONObject:["value":first],options:.sortedKeys),
                  let b=try? JSONSerialization.data(withJSONObject:["value":second],options:.sortedKeys) else{return false}
            return a==b
        }
        return !equal(draft["profiles"],draft["baseProfiles"])
            || !equal(draft["hardware"],base["hardware"])
            || !equal(draft["lighting"],base["lighting"])
    }
    private func syncResult()->[String:Any] {
        ["status":syncMessage,"layerNames":settingsSync?.localSettings?.layerNames ?? []]
    }
    private var resuming=false
    private var resumeFailures=0
    private var lastResumeAttempt:TimeInterval?
    private var previousBoardPresent=false
    private var previousPermissionsGranted=false
    private func resetResumeBackoff(){resumeFailures=0;lastResumeAttempt=nil}
    /// Retry a fresh-login restore or USB return, always using a freshly verified board read.
    func resumeAfterKeyboardReturn()async {
        let boardPresent=KlawosDevicePresence.isPresent
        let permissionsGranted=InputTapController.permissions.values.allSatisfy({$0})
        if HelperStartupPolicy.shouldResetResumeBackoff(previousBoardPresent:previousBoardPresent,boardPresent:boardPresent,
            previousPermissionsGranted:previousPermissionsGranted,permissionsGranted:permissionsGranted){resetResumeBackoff()}
        previousBoardPresent=boardPresent;previousPermissionsGranted=permissionsGranted
        guard (loginResumePending || (helper.wantsOn && helper.capture.lostKeyboard)),!helper.capture.active,!busy,!resuming else{return}
        let vialRunning=NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="today.vial"})
        guard HelperStartupPolicy.shouldAttemptResume(pending:loginResumePending,wantsOn:helper.wantsOn,
            lostKeyboard:helper.capture.lostKeyboard,boardPresent:boardPresent,
            permissionsGranted:permissionsGranted,active:helper.capture.active,busy:busy || resuming,vialRunning:vialRunning,
            failures:resumeFailures,lastAttempt:lastResumeAttempt,now:ProcessInfo.processInfo.systemUptime) else{return}
        resuming=true;defer{resuming=false}
        _ = await perform(Data("{\"operation\":\"helperStart\"}".utf8))
        if helper.capture.active {
            loginResumePending=false;resetResumeBackoff()
        } else {
            resumeFailures=min(resumeFailures+1,6)
            lastResumeAttempt=ProcessInfo.processInfo.systemUptime
        }
    }
    func refreshSettings()async {
        guard let settingsSync,!busy else{return}
        let local=localSettings()
        if let identity=knownIdentity ?? helper.saved.flatMap({ saved in
            saved.definitionHash.map { DeviceIdentity(uid:saved.uid,viaProtocol:9,
                                                       vialProtocol:5,definitionHash:$0) }
        }) {
            let decision=settingsSync.inspect(uid:identity.uid,
                                              definitionHash:identity.definitionHash,local:local)
            switch decision {
            case .unavailable:syncMessage="iCloud Drive is unavailable on this Mac.";return
            case .waiting:syncMessage=syncWaitingMessage;return
            case .invalid:syncMessage="iCloud settings could not be read. Your local settings are safe.";return
            case .conflict:syncMessage="Settings changed on both Macs. Review the conflict before syncing.";return
            case .current:
                if !local.isEmpty || settingsSync.pendingSettings != nil || settingsSync.localSettings != nil {
                    do {
                        switch try settingsSync.publish(uid:identity.uid,
                                                        definitionHash:identity.definitionHash,settings:local) {
                        case .current:syncMessage="Settings are synced with iCloud."
                        case .waiting:syncMessage=syncWaitingMessage
                        case .conflict:syncMessage="Settings changed on both Macs. Review the conflict before syncing."
                        default:syncMessage="iCloud settings could not be saved. Your local settings are safe."
                        }
                    }catch{syncMessage="iCloud settings could not be saved. Your local settings are safe."}
                }else{syncMessage="Settings are synced with iCloud."}
                return
            case .incoming:break
            }
        }
        await receiveSettings(local:local)
    }
    private func receiveSettings(local:SharedSettings)async {
        guard let settingsSync,!busy else{return}
        // The board identity is verified from a fresh read before cloud settings can be applied.
        busy=true;defer{busy=false}
        do {
            let response=try await Worker(resources:resources).request(Data("{\"operation\":\"read\"}".utf8))
            guard let object=try JSONSerialization.jsonObject(with:response) as? [String:Any],
                  object["ok"] as? Bool==true,let wire=object["result"] else{
                syncMessage="Connect KLAWOS to finish iCloud sync.";return
            }
            let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:wire))
            knownIdentity=snapshot.identity
            let decision=settingsSync.inspect(uid:snapshot.identity.uid,
                                              definitionHash:snapshot.identity.definitionHash,local:local)
            switch decision {
            case .unavailable:syncMessage="iCloud Drive is unavailable on this Mac."
            case .waiting:syncMessage=syncWaitingMessage
            case .invalid:syncMessage="iCloud settings could not be read. Your local settings are safe."
            case .conflict:syncMessage="Settings changed on both Macs. Review the conflict before syncing."
            case .current:
                if !local.isEmpty || settingsSync.pendingSettings != nil || settingsSync.localSettings != nil {
                    switch try settingsSync.publish(uid:snapshot.identity.uid,
                                                    definitionHash:snapshot.identity.definitionHash,
                                                    settings:local) {
                    case .current:syncMessage="Settings are synced with iCloud."
                    case .waiting:syncMessage=syncWaitingMessage
                    default:syncMessage="iCloud settings need your attention."
                    }
                } else {syncMessage="Settings are synced with iCloud."}
            case .incoming(let revision):
                guard !draftHasChanges() else{syncMessage="Save or discard your pending changes before syncing.";return}
                guard let allocations=try matchingAllocations(revision.settings.profiles,snapshot:snapshot) else {
                    syncMessage="Connect the keyboard with its saved Mac-action keys to finish syncing.";return
                }
                let wasRunning=helper.capture.active
                try helper.install(profiles:try JSONSerialization.jsonObject(with:JSONEncoder().encode(revision.settings.profiles)),
                                   snapshot:snapshot,allocations:allocations)
                try settingsSync.markApplied(revision)
                syncMessage="Settings are synced with iCloud."
                if wasRunning && !allocations.isEmpty {try? helper.start(snapshot:snapshot)}
            }
        }catch {syncMessage="Connect KLAWOS to finish iCloud sync."}
    }
    private func publishSettings(profiles:[String:Any],payload:[String:Any],snapshot:Snapshot) {
        guard let settingsSync else{syncMessage="iCloud Drive is unavailable on this Mac.";return}
        let names=((payload["projectDocument"] as? [String:Any])?["metadata"] as? [String:Any])?["layerNames"] as? [String]
        guard let data=try? JSONSerialization.data(withJSONObject:profiles),
              let bindings=try? JSONDecoder().decode([InputID:ContextBindings].self,from:data) else{
            syncMessage="These Mac actions could not be synced.";return
        }
        do {
            let settings=SharedSettings(profiles:bindings,layerNames:names ?? settingsSync.pendingSettings?.layerNames ?? settingsSync.localSettings?.layerNames ?? [])
            switch try settingsSync.publish(uid:snapshot.identity.uid,
                                            definitionHash:snapshot.identity.definitionHash,
                                            settings:settings) {
            case .current:syncMessage="Settings are synced with iCloud."
            case .waiting:syncMessage=syncWaitingMessage
            case .unavailable:syncMessage="iCloud Drive is unavailable on this Mac."
            case .conflict:syncMessage="Settings changed on both Macs. Review the conflict before syncing."
            default:syncMessage="iCloud settings could not be saved. Your local settings are safe."
            }
        }catch{syncMessage="iCloud settings could not be saved. Your local settings are safe."}
    }
    private func resolveSync(choice:String)async->[String:Any] {
        guard let settingsSync,!busy,["thisMac","otherMac"].contains(choice) else{
            return ["ok":false,"error":"Sync is busy. Try again in a moment."]
        }
        busy=true;defer{busy=false}
        do {
            let response=try await Worker(resources:resources).request(Data("{\"operation\":\"read\"}".utf8))
            guard let object=try JSONSerialization.jsonObject(with:response) as? [String:Any],
                  object["ok"] as? Bool==true,let wire=object["result"] else{
                return ["ok":false,"error":"Connect KLAWOS before choosing which settings to keep."]
            }
            let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:wire))
            guard !draftHasChanges(),
                  helper.saved?.uid == nil || helper.saved?.uid == snapshot.identity.uid else{
                return ["ok":false,"error":"Save or discard pending edits, then connect the same KLAWOS keyboard before choosing settings."]
            }
            var settings=SharedSettings(profiles:helper.saved?.configuration.bindings ?? [:],layerNames:currentNames())
            if choice=="otherMac" {
                guard let other=try settingsSync.otherMacConflict(uid:snapshot.identity.uid,
                                                                   definitionHash:snapshot.identity.definitionHash),
                      let allocations=try matchingAllocations(other.settings.profiles,snapshot:snapshot) else{
                    return ["ok":false,"error":"The other Mac’s settings need matching Mac-action keys on this keyboard. Save or discard pending edits first."]
                }
                let wasRunning=helper.capture.active
                try helper.install(profiles:try JSONSerialization.jsonObject(with:JSONEncoder().encode(other.settings.profiles)),
                                   snapshot:snapshot,allocations:allocations)
                if wasRunning && !allocations.isEmpty {try? helper.start(snapshot:snapshot)}
                settings=other.settings
            }
            guard case .current = try settingsSync.resolveConflict(uid:snapshot.identity.uid,
                                                                    definitionHash:snapshot.identity.definitionHash,
                                                                    settings:settings) else{
                return ["ok":false,"error":"The conflict changed. Check sync again before choosing."]
            }
            syncMessage="Settings are synced with iCloud."
            return ["ok":true,"result":syncResult()]
        }catch{return ["ok":false,"error":"Could not resolve the settings conflict. Your local settings are safe."]}
    }
    func perform(_ data:Data)async->Data {
        func encoded(_ object:[String:Any])->Data{(try? JSONSerialization.data(withJSONObject:object)) ?? Data()}
        guard data.count<=4*1024*1024,var body=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let operation=body["operation"] as? String else{return encoded(["ok":false,"error":"The app could not read this request. Reopen KLAWOS Studio and try again."])}
        if operation=="helperStatus"{return encoded(["ok":true,"result":helper.status()])}
        if operation=="syncStatus"{await refreshSettings();return encoded(["ok":true,"result":syncResult()])}
        if operation=="syncResolve"{return encoded(await resolveSync(choice:(body["payload"] as? [String:Any])?["choice"] as? String ?? ""))}
        if operation=="helperPermissions"{
            _ = CGRequestListenEventAccess()
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt":true] as CFDictionary)
            return encoded(["ok":true,"result":helper.status()])
        }
        if operation=="helperConfiguration"{await refreshSettings();return (try? JSONSerialization.data(withJSONObject:["ok":true,"result":helper.saved.map{try! JSONSerialization.jsonObject(with:JSONEncoder().encode($0.configuration.bindings))} ?? [:]])) ?? Data()}
        if operation=="helperSetStartAtLogin"{
            guard let enabled=(body["payload"] as? [String:Any])?["enabled"] as? Bool else{return encoded(["ok":false,"error":"Choose whether to start at login."])}
            helper.preferences.startAtLogin=enabled
            return encoded(["ok":true,"result":helper.status()])
        }
        if operation=="helperStop"{loginResumePending=false;resetResumeBackoff();helper.stop();return encoded(["ok":true,"result":helper.status()])}
        if operation=="helperStart" {
            do{
                _ = try await helper.capture.startAfterReading({
                    await self.refreshSettings()
                    guard !self.busy else{throw InputRoutingError.unverifiedConfiguration}
                    self.busy=true;defer{self.busy=false}
                    let response=try await Worker(resources:self.resources).request(encoded(["operation":"read"]))
                    guard let result=try JSONSerialization.jsonObject(with:response) as? [String:Any],result["ok"] as? Bool==true,let wire=result["result"] else{throw InputRoutingError.unverifiedConfiguration}
                    return try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:wire))
                }, activate: { try self.helper.start(snapshot:$0) })
                if helper.capture.active {loginResumePending=false;resetResumeBackoff()}
                return encoded(["ok":true,"result":helper.status()])
            }catch{return encoded(["ok":false,"error":"Could not turn on Mac actions. Allow KLAWOS Helper in Accessibility and Input Monitoring, close Vial, and save your changes to the keyboard first."])}
        }
        guard ["catalog","read","liveLighting","preview","apply","saveDraft","loadDraft","import","export","recoveries","recover","resolveRecovery","security","macroUsage"].contains(operation) else{return encoded(["ok":false,"error":"This action is not available in this version."])}
        guard !busy else{return encoded(["ok":false,"error":"The keyboard is busy. Try again in a moment."])}
        busy=true;defer{busy=false}
        do{
            var allocations:[InputID:String]=[:]
            let wasRunning=helper.capture.active
            if operation=="recover",var payload=body["payload"] as? [String:Any] {
                payload["currentProfiles"]=helper.saved.map{try! JSONSerialization.jsonObject(with:JSONEncoder().encode($0.configuration.bindings))} ?? [:];body["payload"]=payload
            }
            if ["preview","apply"].contains(operation),let payload=body["payload"] as? [String:Any] {
                let prepared=try HelperRuntime.prepare(payload);var preparedPayload=prepared.0
                preparedPayload["previousHelper"]=try helper.saved.map{try JSONSerialization.jsonObject(with:JSONEncoder().encode($0))}
                body["payload"]=preparedPayload;allocations=prepared.1
            }
            if operation=="apply"{helper.stop(explicit:false)}
            let executionGeneration=helper.capture.executionGeneration
            let response=try await Worker(resources:resources).request(JSONSerialization.data(withJSONObject:body))

            if operation=="liveLighting",let payload=body["payload"] as? [String:Any],payload["persist"] as? Bool==true,
               let result=try JSONSerialization.jsonObject(with:response) as? [String:Any],result["ok"] as? Bool==true,
               let content=result["result"] as? [String:Any],let wire=content["base"],let old=payload["base"] as? [String:Any],
               let previousRevision=old["revision"] as? String {
                let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:wire))
                try helper.updateLightingRevision(from:previousRevision,to:snapshot)
            }
            if operation=="apply",let result=try JSONSerialization.jsonObject(with:response) as? [String:Any],result["ok"] as? Bool==true,
               let content=result["result"] as? [String:Any],let snapshotWire=content["snapshot"],let payload=body["payload"] as? [String:Any] {
                let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:snapshotWire))
                knownIdentity=snapshot.identity
                do{
                    let resume=wasRunning && helper.capture.executionGeneration==executionGeneration
                    try helper.install(profiles:payload["profiles"] ?? [:],snapshot:snapshot,allocations:allocations)
                    if resume && !allocations.isEmpty{try helper.start(snapshot:snapshot)}
                }catch{return encoded(["ok":false,"error":"Your keyboard settings were saved, but Mac actions stayed off. Your changes are kept. Try saving again, or open Restore."])}
                publishSettings(profiles:payload["profiles"] as? [String:Any] ?? [:],payload:payload,snapshot:snapshot)
                var updated=result;var updatedContent=content;updatedContent["helperState"]=helper.presentation.state;updated["result"]=updatedContent;return encoded(updated)
            }
            if operation=="saveDraft",let result=try JSONSerialization.jsonObject(with:response) as? [String:Any],
               result["ok"] as? Bool==true,let payload=body["payload"] as? [String:Any],
               let project=payload["projectDocument"] as? [String:Any],
               let metadata=project["metadata"] as? [String:Any],metadata["layerNames"] != nil,
               let base=payload["base"],let snapshot=try? JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:base)) {
                knownIdentity=snapshot.identity
                let installed=helper.saved?.configuration.bindings ?? [:]
                if let data=try? JSONEncoder().encode(installed),
                   let profiles=try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
                    publishSettings(profiles:profiles,payload:payload,snapshot:snapshot)
                }
            }
            if operation=="preview",let payload=body["payload"] as? [String:Any],var decoded=try JSONSerialization.jsonObject(with:response) as? [String:Any],decoded["ok"] as? Bool==true,var result=decoded["result"] as? [String:Any] {
                let old=payload["baseProfiles"] as? [String:Any] ?? [:],new=payload["profiles"] as? [String:Any] ?? [:]
                var changes=result["changes"] as? [[String:Any]] ?? []
                for key in Set(old.keys).union(new.keys).sorted(){let previous=old[key] ?? NSNull(),next=new[key] ?? NSNull();if !NSDictionary(dictionary:["value":previous]).isEqual(to:["value":next]){changes.append(["region":"Mac action · "+key,"before":previous,"after":next])}}
                result["changes"]=changes;decoded["result"]=result;return encoded(decoded)
            }
            return response
        }catch TriggerAllocationError.inheritedLayerConflict{return encoded(["ok":false,"error":"This key shares its first-layer action with another layer. Give it a keyboard action on each other layer first, so the Mac action only runs where you intend."])}catch{return encoded(["ok":false,"error":"The keyboard connection stopped. Your saved changes and backups are safe. Reconnect KLAWOS and try again."])}
    }
}
final class Service:NSObject,AgentRPC,@unchecked Sendable {
    let engine:AgentEngine
    init(engine:AgentEngine){self.engine=engine}
    func perform(_ data:Data,reply:@escaping(Data)->Void){
        let callback=Callback(reply)
        Task{@MainActor in engine.studioRequested=true;callback.call(await engine.perform(data))}
    }
}
final class Callback:@unchecked Sendable {let block:(Data)->Void;init(_ block:@escaping(Data)->Void){self.block=block};func call(_ data:Data){block(data)}}
final class ListenerDelegate:NSObject,NSXPCListenerDelegate {
    let service:Service;let expected:URL
    init(service:Service,expected:URL){self.service=service;self.expected=expected}
    func listener(_ listener:NSXPCListener,shouldAcceptNewConnection connection:NSXPCConnection)->Bool {
        guard AgentPaths.validCaller(connection,expected:expected) else{return false}
        connection.exportedInterface=NSXPCInterface(with:AgentRPC.self);connection.exportedObject=service;connection.resume();return true
    }
}
@MainActor final class MenuController:NSObject,NSApplicationDelegate,NSMenuDelegate {
    let engine:AgentEngine;let appURL:URL;let status:NSMenuItem;let item:NSStatusItem
    private var refreshTimer:Timer?
    let loginItem=NSMenuItem(title:"Start at login",action:#selector(toggleStartAtLogin),keyEquivalent:"")
    init(engine:AgentEngine,appURL:URL,status:NSMenuItem,item:NSStatusItem){
        self.engine=engine;self.appURL=appURL;self.status=status;self.item=item
        super.init()
        loginItem.target=self
        refresh()
        refreshTimer=Timer.scheduledTimer(withTimeInterval:0.5,repeats:true){[weak self]_ in MainActor.assumeIsolated{self?.refresh()}}
    }
    func refresh(){if engine.helper.preferences.startAtLogin || engine.studioRequested {item.isVisible=true};loginItem.state=engine.helper.preferences.startAtLogin ? .on:.off;let title=engine.helper.presentation.menuTitle;status.title=title;item.button?.title="KLAWOS · "+title}
    func menuWillOpen(_ menu:NSMenu){refresh()}
    @objc func start(){Task{@MainActor in _ = await engine.perform(Data("{\"operation\":\"helperStart\"}".utf8));refresh()}}
    @objc func stop(){Task{@MainActor in _ = await engine.perform(Data("{\"operation\":\"helperStop\"}".utf8));refresh()}}
    @objc func toggleStartAtLogin(){engine.helper.preferences.startAtLogin.toggle();refresh()}
    @objc func openEditor(){NSWorkspace.shared.openApplication(at:appURL,configuration:NSWorkspace.OpenConfiguration())}
    // Process termination (including logout/repair) must preserve the user’s action intent.
    func applicationWillTerminate(_ notification:Notification){engine.helper.capture.stop()}
}
let executable=URL(fileURLWithPath:AgentPaths.executablePath(pid:ProcessInfo.processInfo.processIdentifier) ?? CommandLine.arguments[0]).resolvingSymlinksInPath()
let helperContents=executable.deletingLastPathComponent().deletingLastPathComponent()
let contents=helperContents.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let directory=AgentPaths.directory
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
let application=NSApplication.shared;application.setActivationPolicy(.accessory)
let engine=AgentEngine(resources:contents.appendingPathComponent("Resources"));let service=Service(engine:engine)
Timer.scheduledTimer(withTimeInterval:20,repeats:true){_ in Task{@MainActor in
    guard HelperStartupPolicy.shouldStayRunning(startAtLogin:engine.helper.preferences.startAtLogin,studioRequested:engine.studioRequested) else{return}
    await engine.refreshSettings()
}}
Timer.scheduledTimer(withTimeInterval:3,repeats:true){_ in Task{@MainActor in await engine.resumeAfterKeyboardReturn()}}
let listener=NSXPCListener(machServiceName:"com.pippo.klawos.agent");let delegate=ListenerDelegate(service:service,expected:contents.appendingPathComponent("MacOS/KlawosStudio"))
listener.delegate=delegate;listener.resume()
// RunAtLoad and MachServices share this single launchd-owned listener. Give Studio's
// demand-start request time to arrive before a disabled login launch exits quietly.
if !engine.helper.preferences.startAtLogin {
    Timer.scheduledTimer(withTimeInterval:15,repeats:false){_ in MainActor.assumeIsolated{
        if !HelperStartupPolicy.shouldStayRunning(startAtLogin:engine.helper.preferences.startAtLogin,studioRequested:engine.studioRequested){application.terminate(nil)}
    }}
}
let item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength);item.button?.title="KLAWOS"
item.isVisible=engine.helper.preferences.startAtLogin
let menu=NSMenu();let state=NSMenuItem(title:"Mac actions are off",action:nil,keyEquivalent:"");state.isEnabled=false;menu.addItem(state)
let controller=MenuController(engine:engine,appURL:contents.deletingLastPathComponent(),status:state,item:item);application.delegate=controller;menu.delegate=controller
for (title,action) in [("Open KLAWOS Studio",#selector(MenuController.openEditor)),("Turn on Mac actions",#selector(MenuController.start)),("Turn off Mac actions",#selector(MenuController.stop))]{let entry=NSMenuItem(title:title,action:action,keyEquivalent:"");entry.target=controller;menu.addItem(entry)}
menu.addItem(controller.loginItem)
menu.addItem(.separator())
menu.addItem(withTitle:"Quit KLAWOS Helper",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"");item.menu=menu
application.run()
