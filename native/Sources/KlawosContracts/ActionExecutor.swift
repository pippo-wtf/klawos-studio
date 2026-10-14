import Foundation
import AppKit
import ApplicationServices

@MainActor public final class ActionExecutor {
    public init(){}
    public func check(_ action:ActionDescriptor)->Availability {
        do {try ActionValidator.validate(action)}catch{return Availability(state:"unavailable",reason:"Choose a supported action with valid settings.")}
        switch action.kind {
        case "none":return Availability(state:"ready",reason:"")
        case "openApp":
            guard case .string(let id)=action.parameters["bundleID"],NSWorkspace.shared.urlForApplication(withBundleIdentifier:id) != nil else {return Availability(state:"unavailable",reason:"This app is not installed on this Mac.")}
        case "shortcut","menuCommand":
            guard AXIsProcessTrusted() else {return Availability(state:"unavailable",reason:"Enable Accessibility for KLAWOS Studio in System Settings.")}
            if action.kind=="menuCommand",menuItem(action)==nil{return Availability(state:"unavailable",reason:"The specified enabled menu item is not available in the foreground app.")}
        case "namedShortcut":return Availability(state:"unknown",reason:"The named macOS Shortcut is checked when run; unavailable shortcuts report a failure.")
        default:return Availability(state:"unavailable",reason:"This action has not been verified.")
        }
        return Availability(state:"ready",reason:"")
    }
    public func execute(_ action:ActionDescriptor)async->ActionResult {
        let availability=check(action)
        guard availability.state != "unavailable" else{return ActionResult(actionID:action.id ?? action.kind,state:"unavailable",reason:availability.reason)}
        do {
            switch action.kind {
            case "none":break
            case "openApp":
                guard case .string(let id)=action.parameters["bundleID"],let url=NSWorkspace.shared.urlForApplication(withBundleIdentifier:id) else {throw ActionValidationError.invalidParameters}
                // Launch request is asynchronous; no wait on the event-tap callback.
                let config=NSWorkspace.OpenConfiguration();config.activates=true
                _ = try await NSWorkspace.shared.openApplication(at:url,configuration:config)
            case "shortcut":
                guard case .integer(let key)=action.parameters["keyCode"],case .array(let modifiers)=action.parameters["modifiers"] else {throw ActionValidationError.invalidParameters}
                var flags=CGEventFlags();for mod in modifiers {switch mod{case .string("command"):flags.insert(.maskCommand);case .string("control"):flags.insert(.maskControl);case .string("option"):flags.insert(.maskAlternate);case .string("shift"):flags.insert(.maskShift);default:break}}
                guard let down=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(key),keyDown:true),let up=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(key),keyDown:false) else {throw ActionValidationError.invalidParameters}
                for event in [down,up]{event.flags=flags;event.setIntegerValueField(.eventSourceUserData,value:MacInputEvent.syntheticMarker);event.post(tap:.cghidEventTap)}
            case "menuCommand":
                guard let item=menuItem(action),AXUIElementPerformAction(item,kAXPressAction as CFString) == .success else {throw ActionValidationError.invalidParameters}
            case "namedShortcut":
                guard case .string(let name)=action.parameters["name"] else {throw ActionValidationError.invalidParameters}
                let success=await Self.runShortcut(name)
                guard success else {return ActionResult(actionID:action.id ?? action.kind,state:"failed",reason:"Shortcut was missing, failed, or exceeded the two-second limit.")}
            default:throw ActionValidationError.unsupportedAction
            }
            return ActionResult(actionID:action.id ?? action.kind,state:"executed",reason:"")
        }catch{return ActionResult(actionID:action.id ?? action.kind,state:"failed",reason:"The action could not be completed in the current app.")}
    }
    private func menuItem(_ action:ActionDescriptor)->AXUIElement? {
        guard AXIsProcessTrusted(),case .string(let bundle)=action.parameters["bundleID"],NSWorkspace.shared.frontmostApplication?.bundleIdentifier==bundle,
              let pid=NSWorkspace.shared.frontmostApplication?.processIdentifier,case .array(let path)=action.parameters["menuPath"] else{return nil}
        let app=AXUIElementCreateApplication(pid);AXUIElementSetMessagingTimeout(app,0.15)
        var root:CFTypeRef?;guard AXUIElementCopyAttributeValue(app,kAXMenuBarAttribute as CFString,&root) == .success,let root else{return nil}
        var current=root as! AXUIElement
        for component in path {
            guard case .string(let title)=component else{return nil}
            var value:CFTypeRef?;guard AXUIElementCopyAttributeValue(current,kAXChildrenAttribute as CFString,&value) == .success,let children=value as? [AXUIElement] else{return nil}
            // A menu item commonly wraps its submenu in an AXMenu child.
            var candidates=children
            if children.count==1 {var role:CFTypeRef?;AXUIElementCopyAttributeValue(children[0],kAXRoleAttribute as CFString,&role);if role as? String==kAXMenuRole {var items:CFTypeRef?;AXUIElementCopyAttributeValue(children[0],kAXChildrenAttribute as CFString,&items);candidates=items as? [AXUIElement] ?? []}}
            let matches=candidates.filter{element in var value:CFTypeRef?;AXUIElementCopyAttributeValue(element,kAXTitleAttribute as CFString,&value);return value as? String==title}
            guard matches.count==1 else{return nil};current=matches[0]
        }
        var enabled:CFTypeRef?;guard AXUIElementCopyAttributeValue(current,kAXEnabledAttribute as CFString,&enabled) == .success,enabled as? Bool==true else{return nil};return current
    }
    nonisolated private static func runShortcut(_ name:String)async->Bool {
        await withCheckedContinuation{continuation in DispatchQueue.global().async{
            let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/shortcuts");process.arguments=["run",name];process.standardOutput=FileHandle.nullDevice;process.standardError=FileHandle.nullDevice;process.standardInput=FileHandle.nullDevice
            do{try process.run();let deadline=Date().addingTimeInterval(2);while process.isRunning && Date()<deadline{Thread.sleep(forTimeInterval:0.025)};if process.isRunning{process.terminate();continuation.resume(returning:false)}else{continuation.resume(returning:process.terminationStatus==0)}}catch{continuation.resume(returning:false)}
        }}
    }
}
