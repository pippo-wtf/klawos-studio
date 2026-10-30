import Cocoa
import WebKit
import UniformTypeIdentifiers
import ServiceManagement
import KlawosContracts

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandlerWithReply, WKNavigationDelegate {
    var window:NSWindow!;var web:WKWebView!;var busy=false;let recorder=ForegroundRecorder()
    let resources=Bundle.main.resourceURL!
    func applicationDidFinishLaunching(_ notification:Notification) {
        if let icon=NSImage(contentsOf:resources.appendingPathComponent("Klawos.icns")){NSApp.applicationIconImage=icon}
        Task{@MainActor in
            let client=AgentClient(resources:resources)
            try? await client.launch()
            // Establish Studio demand before the helper's quiet-exit deadline.
            _ = try? await client.request(Data("{\"operation\":\"helperStatus\"}".utf8))
            for _ in 0..<4 {
                try? await Task.sleep(nanoseconds:3_000_000_000)
                guard let status=try? await client.request(Data("{\"operation\":\"helperStatus\"}".utf8)),let state=((try? JSONSerialization.jsonObject(with:status)) as? [String:Any])?["result"] as? [String:Any] else{continue}
                if ["running","paused"].contains(state["state"] as? String){return}
                if let started=try? await client.request(Data("{\"operation\":\"helperStart\"}".utf8)),((try? JSONSerialization.jsonObject(with:started)) as? [String:Any])?["ok"] as? Bool==true{return}
            }
        }
        let menu=NSMenu();let appItem=NSMenuItem();menu.addItem(appItem);let appMenu=NSMenu();appItem.submenu=appMenu
        let about=appMenu.addItem(withTitle:"About KLAWOS Studio",action:#selector(showAbout),keyEquivalent:"");about.target=self
        appMenu.addItem(.separator());appMenu.addItem(withTitle:"Quit KLAWOS Studio",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        let editItem=NSMenuItem();menu.addItem(editItem);let edit=NSMenu(title:"Edit");editItem.submenu=edit
        for (title,action,key) in [("Undo","undo:","z"),("Cut","cut:","x"),("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")] { edit.addItem(withTitle:title,action:Selector(action),keyEquivalent:key) }
        NSApp.mainMenu=menu
        let configuration=WKWebViewConfiguration();configuration.setURLSchemeHandler(Assets(root:resources.appendingPathComponent("ui")),forURLScheme:"klawos");configuration.userContentController.addScriptMessageHandler(self,contentWorld:.page,name:"klawos")
        web=WKWebView(frame:.zero,configuration:configuration);web.navigationDelegate=self
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1280,height:860),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="KLAWOS Studio";window.minSize=NSSize(width:880,height:640);window.contentView=web;window.center();window.makeKeyAndOrderFront(nil)
        web.load(URLRequest(url:URL(string:"klawos://app/index.html")!))
        NSApp.activate(ignoringOtherApps:true)
    }
    @objc func showAbout(){
        var options:[NSApplication.AboutPanelOptionKey:Any]=[:]
        if let icon=NSImage(contentsOf:resources.appendingPathComponent("Klawos.icns")){options[.applicationIcon]=icon}
        NSApp.orderFrontStandardAboutPanel(options:options)
    }
    func applicationDidResignActive(_ notification:Notification){recorder.stop()}
    func applicationWillTerminate(_ notification:Notification){recorder.stop()}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping @MainActor @Sendable (WKNavigationActionPolicy)->Void) {
        decisionHandler(navigationAction.request.url.map { $0.scheme=="klawos" && $0.host=="app" } == true ? .allow:.cancel)
    }
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage,replyHandler:@escaping @MainActor @Sendable (Any?,String?)->Void) {
        guard message.frameInfo.isMainFrame,let url=message.frameInfo.request.url,url.scheme=="klawos",url.host=="app",
              var body=message.body as? [String:Any],let operation=body["operation"] as? String,
              ["read","catalog","liveLighting","preview","apply","saveDraft","loadDraft","import","export","recoveries","recover","resolveRecovery","security","macroUsage","recordingStart","recordingStop","recordingStatus","helperStatus","helperSetStartAtLogin","helperStart","helperStop","helperConfiguration","syncStatus","syncResolve","actionCatalog","helperPermissions","diagnostics","repairHelper","hideForTest"].contains(operation),
              let raw=try? JSONSerialization.data(withJSONObject:body),raw.count<=4*1024*1024 else {replyHandler(nil,"The app could not use this request. Reopen KLAWOS Studio and try again.");return}
        if operation=="hideForTest" {
            recorder.stop();replyHandler(["ok":true,"result":["hidden":true]],nil);NSApp.hide(nil);return
        }
        if operation=="repairHelper" {
            Task{@MainActor in
                do{try await SMAppService.agent(plistName:"com.pippo.klawos.agent.plist").unregister();try await AgentClient(resources:resources).launch();replyHandler(["ok":true,"result":["restarted":true]],nil)}catch{replyHandler(nil,"Could not restart Mac actions. Allow KLAWOS Studio in System Settings → General → Login Items & Extensions.")}
            };return
        }
        if operation=="apply" && recorder.core.active{replyHandler(nil,"Stop recording before saving to your keyboard.");return}
        if operation=="diagnostics" {
            do{
                let payload=body["payload"] as? [String:Any] ?? [:]
                let state=try JSONDecoder().decode(JSONObject.self,from:JSONSerialization.data(withJSONObject:payload))
                let data=try JSONEncoder().encode(Diagnostics.redacted(state))
                let panel=NSSavePanel();panel.nameFieldStringValue="KLAWOS-diagnostics.json"
                guard panel.runModal() == .OK,let url=panel.url else{replyHandler(nil,"Export cancelled.");return}
                try data.write(to:url,options:.atomic);replyHandler(["ok":true,"result":["saved":true]],nil)
            }catch{replyHandler(nil,"Could not save the support info. Choose another folder and try again.")};return
        }
        if operation=="actionCatalog" {
            var apps:[[String:String]]=[]
            for directory in [URL(fileURLWithPath:"/Applications"),URL(fileURLWithPath:"/System/Applications"),FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")] {
                let files=(try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? []
                for url in files where url.pathExtension=="app" {
                    if let bundle=Bundle(url:url),let id=bundle.bundleIdentifier{apps.append(["bundleID":id,"name":bundle.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? url.deletingPathExtension().lastPathComponent])}
                }
            }
            let keys=MacKeycodes.qmk.map{["keyCode":Int($0.key),"name":$0.value.replacingOccurrences(of:"KC_",with:"")] as [String:Any]}.sorted{($0["name"] as! String)<($1["name"] as! String)}
            replyHandler(["ok":true,"result":["apps":apps.sorted{$0["name"]!<$1["name"]!},"keys":keys]],nil);return
        }
        if operation.hasPrefix("recording") {
            if operation=="recordingStart"{
                let payload=body["payload"] as? [String:Any] ?? [:]
                do{try recorder.start(captureEscape:payload["captureEscape"] as? Bool ?? false)}catch{replyHandler(nil,error.localizedDescription);return}
            }
            if operation=="recordingStop"{recorder.stop()}
            replyHandler(["ok":true,"result":recorder.state()],nil);return
        }
        guard !busy else {replyHandler(nil,"The keyboard is busy. Try again in a moment.");return}
        if operation=="import" {
            let panel=NSOpenPanel();panel.allowedContentTypes=[.json,UTType(filenameExtension:"vil") ?? .data,UTType(filenameExtension:"klawos") ?? .data];panel.allowsMultipleSelection=false
            guard panel.runModal() == .OK,let selected=panel.url,let data=try? Data(contentsOf:selected),data.count<=4*1024*1024,let document=String(data:data,encoding:.utf8) else {replyHandler(nil,"No file was imported. Choose a KLAWOS or Vial file smaller than 4 MB.");return}
            var payload=body["payload"] as? [String:Any] ?? [:];payload["document"]=document;body["payload"]=payload
        }
        busy=true
        Task { @MainActor in
            defer {busy=false}
            do {
                let data=try JSONSerialization.data(withJSONObject:body)
                let response=try await AgentClient(resources:resources).request(data)
                guard let object=try JSONSerialization.jsonObject(with:response) as? [String:Any] else {throw NSError(domain:"KLAWOS",code:2)}
                if operation=="export",object["ok"] as? Bool==true,let result=object["result"] as? [String:Any],let document=result["document"] as? String {
                    let panel=NSSavePanel();let payload=body["payload"] as? [String:Any];panel.nameFieldStringValue="KLAWOS."+((payload?["format"] as? String)=="vil" ? "vil":"klawos")
                    guard panel.runModal() == .OK,let destination=panel.url else {replyHandler(nil,"Export cancelled.");return}
                    try Data(document.utf8).write(to:destination,options:.atomic)
                    replyHandler(["ok":true,"result":["saved":true]],nil)
                } else {replyHandler(object,nil)}
            } catch {replyHandler(nil,"Could not finish. Your saved changes and backups are safe. Reopen KLAWOS Studio and try again.")}
        }
    }
}
let application=NSApplication.shared
if CommandLine.arguments.contains("--integration-check") || CommandLine.arguments.contains("--refresh-helper-registration"){application.setActivationPolicy(.accessory);integrationCheck();application.run();exit(0)}
let delegate=AppDelegate();application.delegate=delegate;application.setActivationPolicy(.regular);application.run()
