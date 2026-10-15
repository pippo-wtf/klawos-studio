import Foundation
import AppKit
import ApplicationServices

@MainActor public final class ActionExecutor {
    @MainActor struct AppEnvironment {
        var applicationURL: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        var accessibilityGranted: () -> Bool = { AXIsProcessTrusted() }
        var frontmostBundleID: () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
        var openApplication: (URL) async throws -> Void = { url in
            let config = NSWorkspace.OpenConfiguration(); config.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
        var postShortcut: (Int64, [JSONValue]) throws -> Void = { try ActionExecutor.postShortcut(key: $0, modifiers: $1) }
    }
    private let apps: AppEnvironment
    public init(){ apps = AppEnvironment() }
    init(apps: AppEnvironment){ self.apps = apps }
    public func check(_ action:ActionDescriptor)->Availability {
        do {try ActionValidator.validate(action)}catch{return Availability(state:"unavailable",reason:"Check this action’s settings and try again.")}
        switch action.kind {
        case "none":return Availability(state:"ready",reason:"")
        case "openApp":
            guard case .string(let id)=action.parameters["bundleID"],apps.applicationURL(id) != nil else {return Availability(state:"unavailable",reason:"This app is not installed on this Mac.")}
        case "shortcut","menuCommand","appShortcut":
            guard apps.accessibilityGranted() else {return Availability(state:"unavailable",reason:"Allow KLAWOS Helper in System Settings → Privacy & Security → Accessibility.")}
            if action.kind=="menuCommand",menuItem(action)==nil{return Availability(state:"unavailable",reason:"That menu item is not available. Open the chosen app and check the menu names.")}
            if action.kind=="appShortcut",case .string(let id)=action.parameters["bundleID"],
               apps.applicationURL(id)==nil {
                return Availability(state:"unavailable",reason:"This app is not installed on this Mac.")
            }
        case "openURL":
            guard apps.applicationURL("com.anthropic.claudefordesktop") != nil else {
                return Availability(state:"unavailable",reason:"Claude is not installed on this Mac.")
            }
        case "namedShortcut":return Availability(state:"unknown",reason:"The Shortcut will be checked when you run it.")
        default:return Availability(state:"unavailable",reason:"This action is not available yet.")
        }
        return Availability(state:"ready",reason:"")
    }
    public func execute(_ action:ActionDescriptor, isValid: () -> Bool = { true })async->ActionResult {
        func cancelled() -> ActionResult { ActionResult(actionID: action.id ?? action.kind, state: "cancelled", reason: "Mac action cancelled because the helper state changed.") }
        guard isValid(), !Task.isCancelled else { return cancelled() }
        let availability=check(action)
        guard availability.state != "unavailable" else{return ActionResult(actionID:action.id ?? action.kind,state:"unavailable",reason:availability.reason)}
        do {
            switch action.kind {
            case "none":break
            case "openApp":
                guard case .string(let id)=action.parameters["bundleID"],let url=apps.applicationURL(id) else {throw ActionValidationError.invalidParameters}
                // Launch request is asynchronous; no wait on the event-tap callback.
                try await apps.openApplication(url)
                guard isValid(), !Task.isCancelled else { return cancelled() }
            case "shortcut":
                guard case .integer(let key)=action.parameters["keyCode"],case .array(let modifiers)=action.parameters["modifiers"] else {throw ActionValidationError.invalidParameters}
                try apps.postShortcut(key,modifiers)
            case "appShortcut":
                guard case .string(let id)=action.parameters["bundleID"],
                      case .integer(let key)=action.parameters["keyCode"],
                      case .array(let modifiers)=action.parameters["modifiers"],
                      let url=apps.applicationURL(id) else {throw ActionValidationError.invalidParameters}
                try await apps.openApplication(url)
                for _ in 0..<40 {
                    guard isValid(), !Task.isCancelled else { return cancelled() }
                    if apps.frontmostBundleID()==id {break}
                    try await Task.sleep(for:.milliseconds(50))
                }
                guard apps.frontmostBundleID()==id else {
                    return ActionResult(actionID:action.id ?? action.kind,state:"failed",reason:"Could not bring the chosen app forward. Open it and try again.")
                }
                guard isValid(), !Task.isCancelled else { return cancelled() }
                try apps.postShortcut(key,modifiers)
            case "openURL":
                guard case .string(let raw)=action.parameters["url"],let url=URL(string:raw),
                      NSWorkspace.shared.open(url) else {throw ActionValidationError.invalidParameters}
            case "menuCommand":
                guard let item=menuItem(action),AXUIElementPerformAction(item,kAXPressAction as CFString) == .success else {throw ActionValidationError.invalidParameters}
            case "namedShortcut":
                guard case .string(let name)=action.parameters["name"] else {throw ActionValidationError.invalidParameters}
                let success=await Self.runShortcut(name, isValid: isValid)
                guard isValid(), !Task.isCancelled else { return cancelled() }
                guard success else {return ActionResult(actionID:action.id ?? action.kind,state:"failed",reason:"The Shortcut could not finish within 2 seconds. Check its name and try it in Shortcuts.")}
            default:throw ActionValidationError.unsupportedAction
            }
            return ActionResult(actionID:action.id ?? action.kind,state:"executed",reason:"")
        }catch{
            guard isValid(), !Task.isCancelled else { return cancelled() }
            return ActionResult(actionID:action.id ?? action.kind,state:"failed",reason:"The action did not work. Check the app and action settings, then try again.")}
    }
    private static func postShortcut(key:Int64,modifiers:[JSONValue])throws {
        var flags=CGEventFlags();for mod in modifiers {switch mod{case .string("command"):flags.insert(.maskCommand);case .string("control"):flags.insert(.maskControl);case .string("option"):flags.insert(.maskAlternate);case .string("shift"):flags.insert(.maskShift);default:break}}
        guard let down=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(key),keyDown:true),
              let up=CGEvent(keyboardEventSource:nil,virtualKey:CGKeyCode(key),keyDown:false) else {throw ActionValidationError.invalidParameters}
        for event in [down,up]{event.flags=flags;event.setIntegerValueField(.eventSourceUserData,value:MacInputEvent.syntheticMarker);event.post(tap:.cghidEventTap)}
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
    private static func runShortcut(_ name:String, isValid: () -> Bool) async -> Bool {
        guard isValid(), !Task.isCancelled else { return false }
        let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/shortcuts");process.arguments=["run",name];process.standardOutput=FileHandle.nullDevice;process.standardError=FileHandle.nullDevice;process.standardInput=FileHandle.nullDevice
        do {
            // Launch on this actor so Stop cannot overtake a queued background launch.
            try process.run()
            let deadline=Date().addingTimeInterval(2)
            while process.isRunning && Date()<deadline && isValid() && !Task.isCancelled {
                try await Task.sleep(for:.milliseconds(25))
            }
            if process.isRunning { process.terminate(); return false }
            return process.terminationStatus==0
        } catch {
            if process.isRunning { process.terminate() }
            return false
        }
    }
}
