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
        guard data.count<=4*1024*1024,var body=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let operation=body["operation"] as? String else{return encoded(["ok":false,"error":"Invalid app request."])}
        if operation=="helperStatus"{return encoded(["ok":true,"result":helper.status()])}
        if operation=="helperPermissions"{
            _ = CGRequestListenEventAccess()
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt":true] as CFDictionary)
            return encoded(["ok":true,"result":helper.status()])
        }
        if operation=="helperConfiguration"{return (try? JSONSerialization.data(withJSONObject:["ok":true,"result":helper.saved.map{try! JSONSerialization.jsonObject(with:JSONEncoder().encode($0.configuration.bindings))} ?? [:]])) ?? Data()}
        if operation=="helperStop"{helper.stop();return encoded(["ok":true,"result":helper.status()])}
        if operation=="helperStart" {
            guard !busy else{return encoded(["ok":false,"error":"A keyboard operation is running."])}
            busy=true;defer{busy=false}
            do{
                let response=try await Worker(resources:resources).request(encoded(["operation":"read"]))
                guard let result=try JSONSerialization.jsonObject(with:response) as? [String:Any],result["ok"] as? Bool==true,let wire=result["result"] else{throw InputRoutingError.unverifiedConfiguration}
                let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:wire))
                try helper.start(snapshot:snapshot);return encoded(["ok":true,"result":helper.status()])
            }catch{return encoded(["ok":false,"error":"Mac actions could not start. Enable Accessibility and Input Monitoring for KLAWOS, close Vial, and Apply the current configuration before trying again."])}
        }
        guard ["catalog","read","preview","apply","saveDraft","loadDraft","import","export","recoveries","recover","resolveRecovery","security","macroUsage"].contains(operation) else{return encoded(["ok":false,"error":"Unsupported app operation."])}
        guard !busy else{return encoded(["ok":false,"error":"Another keyboard operation is in progress."])}
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
                }catch{return encoded(["ok":false,"error":"Keyboard changes were verified, but Mac actions could not be activated. They remain stopped. Your draft is retained; reapply or use recovery."])}
                var updated=result;var updatedContent=content;updatedContent["helperState"]=helper.capture.active ? "running":"stopped";updated["result"]=updatedContent;return encoded(updated)
            }
            if operation=="preview",let payload=body["payload"] as? [String:Any],var decoded=try JSONSerialization.jsonObject(with:response) as? [String:Any],decoded["ok"] as? Bool==true,var result=decoded["result"] as? [String:Any] {
                let old=payload["baseProfiles"] as? [String:Any] ?? [:],new=payload["profiles"] as? [String:Any] ?? [:]
                var changes=result["changes"] as? [[String:Any]] ?? []
                for key in Set(old.keys).union(new.keys).sorted(){let previous=old[key] ?? NSNull(),next=new[key] ?? NSNull();if !NSDictionary(dictionary:["value":previous]).isEqual(to:["value":next]){changes.append(["region":"Mac action · "+key,"before":previous,"after":next])}}
                result["changes"]=changes;decoded["result"]=result;return encoded(decoded)
            }
            return response
        }catch TriggerAllocationError.inheritedLayerConflict{return encoded(["ok":false,"error":"This Work key is inherited by another layer. Set an explicit keyboard assignment for that key on every other layer before assigning a Mac action, so gaming keys cannot trigger the helper."])}catch{return encoded(["ok":false,"error":"The device worker stopped. Your draft and backups are retained."])}
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
    @objc func start(){Task{@MainActor in _ = await engine.perform(Data("{\"operation\":\"helperStart\"}".utf8));status.title=engine.helper.capture.active ? "Mac actions running":"Mac actions stopped"}}
    @objc func stop(){engine.helper.stop();status.title="Mac actions stopped"}
    @objc func openEditor(){NSWorkspace.shared.openApplication(at:appURL,configuration:NSWorkspace.OpenConfiguration())}
    func applicationWillTerminate(_ notification:Notification){engine.helper.stop()}
}
let executable=URL(fileURLWithPath:AgentPaths.executablePath(pid:ProcessInfo.processInfo.processIdentifier) ?? CommandLine.arguments[0]).resolvingSymlinksInPath()
let contents=executable.deletingLastPathComponent().deletingLastPathComponent()
let directory=AgentPaths.directory
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
let application=NSApplication.shared;application.setActivationPolicy(.accessory)
let engine=AgentEngine(resources:contents.appendingPathComponent("Resources"));let service=Service(engine:engine)
let listener=NSXPCListener(machServiceName:"com.pippo.klawos.agent");let delegate=ListenerDelegate(service:service,expected:contents.appendingPathComponent("MacOS/KlawosStudio"))
listener.delegate=delegate;listener.resume()
let item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength);item.button?.title="KLAWOS"
let menu=NSMenu();let state=NSMenuItem(title:"Mac actions stopped",action:nil,keyEquivalent:"");state.isEnabled=false;menu.addItem(state)
let controller=MenuController(engine:engine,appURL:contents.deletingLastPathComponent(),status:state);application.delegate=controller
for (title,action) in [("Open editor",#selector(MenuController.openEditor)),("Start Mac actions",#selector(MenuController.start)),("Stop Mac actions",#selector(MenuController.stop))]{let entry=NSMenuItem(title:title,action:action,keyEquivalent:"");entry.target=controller;menu.addItem(entry)}
menu.addItem(.separator())
menu.addItem(withTitle:"Quit helper",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"");item.menu=menu
application.run()
