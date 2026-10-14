import Cocoa
import Foundation
import Darwin
import ApplicationServices
import KlawosContracts

@MainActor final class AgentEngine {
    let resources:URL
    var busy=false;let helper=HelperRuntime()
    init(resources:URL){self.resources=resources}
    func perform(_ data:Data)async->Data {
        func encoded(_ object:[String:Any])->Data{(try? JSONSerialization.data(withJSONObject:object)) ?? Data()}
        guard data.count<=4*1024*1024,var body=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let operation=body["operation"] as? String else{return encoded(["ok":false,"error":"The app could not read this request. Reopen KLAWOS Studio and try again."])}
        if operation=="helperStatus"{return encoded(["ok":true,"result":helper.status()])}
        if operation=="helperPermissions"{
            _ = CGRequestListenEventAccess()
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt":true] as CFDictionary)
            return encoded(["ok":true,"result":helper.status()])
        }
        if operation=="helperConfiguration"{return (try? JSONSerialization.data(withJSONObject:["ok":true,"result":helper.saved.map{try! JSONSerialization.jsonObject(with:JSONEncoder().encode($0.configuration.bindings))} ?? [:]])) ?? Data()}
        if operation=="helperStop"{helper.stop();return encoded(["ok":true,"result":helper.status()])}
        if operation=="helperStart" {
            guard !busy else{return encoded(["ok":false,"error":"The keyboard is busy. Try again in a moment."])}
            busy=true;defer{busy=false}
            do{
                let response=try await Worker(resources:resources).request(encoded(["operation":"read"]))
                guard let result=try JSONSerialization.jsonObject(with:response) as? [String:Any],result["ok"] as? Bool==true,let wire=result["result"] else{throw InputRoutingError.unverifiedConfiguration}
                let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:wire))
                try helper.start(snapshot:snapshot);return encoded(["ok":true,"result":helper.status()])
            }catch{return encoded(["ok":false,"error":"Could not turn on Mac actions. Allow KLAWOS Helper in Accessibility and Input Monitoring, close Vial, and save your changes to the keyboard first."])}
        }
        guard ["catalog","read","preview","apply","saveDraft","loadDraft","import","export","recoveries","recover","resolveRecovery","security","macroUsage"].contains(operation) else{return encoded(["ok":false,"error":"This action is not available in this version."])}
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
            if operation=="apply"{helper.stop()}
            let response=try await Worker(resources:resources).request(JSONSerialization.data(withJSONObject:body))
            if operation=="apply",let result=try JSONSerialization.jsonObject(with:response) as? [String:Any],result["ok"] as? Bool==true,
               let content=result["result"] as? [String:Any],let snapshotWire=content["snapshot"],let payload=body["payload"] as? [String:Any] {
                let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:snapshotWire))
                do{
                    try helper.install(profiles:payload["profiles"] ?? [:],snapshot:snapshot,allocations:allocations)
                    if wasRunning && !allocations.isEmpty{try helper.start(snapshot:snapshot)}
                }catch{return encoded(["ok":false,"error":"Your keyboard settings were saved, but Mac actions stayed off. Your changes are kept. Try saving again, or open Restore."])}
                var updated=result;var updatedContent=content;updatedContent["helperState"]=helper.capture.active ? "running":"stopped";updated["result"]=updatedContent;return encoded(updated)
            }
            if operation=="preview",let payload=body["payload"] as? [String:Any],var decoded=try JSONSerialization.jsonObject(with:response) as? [String:Any],decoded["ok"] as? Bool==true,var result=decoded["result"] as? [String:Any] {
                let old=payload["baseProfiles"] as? [String:Any] ?? [:],new=payload["profiles"] as? [String:Any] ?? [:]
                var changes=result["changes"] as? [[String:Any]] ?? []
                for key in Set(old.keys).union(new.keys).sorted(){let previous=old[key] ?? NSNull(),next=new[key] ?? NSNull();if !NSDictionary(dictionary:["value":previous]).isEqual(to:["value":next]){changes.append(["region":"Mac action · "+key,"before":previous,"after":next])}}
                result["changes"]=changes;decoded["result"]=result;return encoded(decoded)
            }
            return response
        }catch TriggerAllocationError.inheritedLayerConflict{return encoded(["ok":false,"error":"This key shares its Work action with another layer. Give it a keyboard action on each other layer first, so it won’t run a Mac action while gaming."])}catch{return encoded(["ok":false,"error":"The keyboard connection stopped. Your saved changes and backups are safe. Reconnect KLAWOS and try again."])}
    }
}
final class Service:NSObject,AgentRPC,@unchecked Sendable {
    let engine:AgentEngine
    init(engine:AgentEngine){self.engine=engine}
    func perform(_ data:Data,reply:@escaping(Data)->Void){
        let callback=Callback(reply)
        Task{@MainActor in callback.call(await engine.perform(data))}
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
@MainActor final class MenuController:NSObject,NSApplicationDelegate {
    let engine:AgentEngine;let appURL:URL;let status:NSMenuItem
    init(engine:AgentEngine,appURL:URL,status:NSMenuItem){self.engine=engine;self.appURL=appURL;self.status=status}
    @objc func start(){Task{@MainActor in _ = await engine.perform(Data("{\"operation\":\"helperStart\"}".utf8));status.title=engine.helper.capture.active ? "Mac actions are on":"Mac actions are off"}}
    @objc func stop(){engine.helper.stop();status.title="Mac actions are off"}
    @objc func openEditor(){NSWorkspace.shared.openApplication(at:appURL,configuration:NSWorkspace.OpenConfiguration())}
    func applicationWillTerminate(_ notification:Notification){engine.helper.stop()}
}
let executable=URL(fileURLWithPath:AgentPaths.executablePath(pid:ProcessInfo.processInfo.processIdentifier) ?? CommandLine.arguments[0]).resolvingSymlinksInPath()
let helperContents=executable.deletingLastPathComponent().deletingLastPathComponent()
let contents=helperContents.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let directory=AgentPaths.directory
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
let application=NSApplication.shared;application.setActivationPolicy(.accessory)
let engine=AgentEngine(resources:contents.appendingPathComponent("Resources"));let service=Service(engine:engine)
let listener=NSXPCListener(machServiceName:"com.pippo.klawos.agent");let delegate=ListenerDelegate(service:service,expected:contents.appendingPathComponent("MacOS/KlawosStudio"))
listener.delegate=delegate;listener.resume()
let item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength);item.button?.title="KLAWOS"
let menu=NSMenu();let state=NSMenuItem(title:"Mac actions are off",action:nil,keyEquivalent:"");state.isEnabled=false;menu.addItem(state)
let controller=MenuController(engine:engine,appURL:contents.deletingLastPathComponent(),status:state);application.delegate=controller
for (title,action) in [("Open KLAWOS Studio",#selector(MenuController.openEditor)),("Turn on Mac actions",#selector(MenuController.start)),("Turn off Mac actions",#selector(MenuController.stop))]{let entry=NSMenuItem(title:title,action:action,keyEquivalent:"");entry.target=controller;menu.addItem(entry)}
menu.addItem(.separator())
menu.addItem(withTitle:"Quit KLAWOS Helper",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"");item.menu=menu
application.run()
