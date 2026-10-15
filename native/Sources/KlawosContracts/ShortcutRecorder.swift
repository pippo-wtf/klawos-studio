import AppKit
import Carbon

/// Explicit foreground recording: protects input from other apps and suspends hotkeys.
@MainActor public final class ShortcutRecorder {
    public let core=MacroRecorderCore()
    private var modifiers=RecorderModifiers(heldKeys:[])
    private var captureEscape=false
    private var cleanup:(()->Void)?
    private var timer:Timer?
    private var deadline:TimeInterval=0
    private let trusted:()->Bool
    private let frontmost:()->Bool
    private let now:()->TimeInterval
    private let held:()->Set<UInt16>
    private let install:(ShortcutRecorder)->(()->Void)?

    public convenience init(){self.init(trusted:{AXIsProcessTrusted()},frontmost:{NSApp.isActive},
        now:{ProcessInfo.processInfo.systemUptime},
        held:{Set(MacKeycodes.modifiers.filter{CGEventSource.keyState(.combinedSessionState,key:$0)})},
        install:Self.installCapture)}
    init(trusted:@escaping ()->Bool,frontmost:@escaping ()->Bool,now:@escaping ()->TimeInterval,
         held:@escaping ()->Set<UInt16>,install:@escaping (ShortcutRecorder)->(()->Void)?){
        self.trusted=trusted;self.frontmost=frontmost;self.now=now;self.held=held;self.install=install
    }
    public func start(captureEscape:Bool=false) throws {
        stop()
        guard frontmost() else{throw RecordingError.keepInFront}
        guard trusted() else{throw RecordingError.permissionRequired}
        let heldKeys=held()
        guard let cleanup=install(self) else{throw RecordingError.captureUnavailable}
        self.cleanup=cleanup;self.captureEscape=captureEscape
        modifiers=RecorderModifiers(heldKeys:heldKeys);deadline=now()+35
        core.start(heldModifiers:modifiers.keys,time:now())
        timer=Timer.scheduledTimer(withTimeInterval:0.25,repeats:true){[weak self] _ in
            MainActor.assumeIsolated{self?.checkSession()}
        }
    }
    public func stop(){
        core.stop();timer?.invalidate();timer=nil
        let release=cleanup;cleanup=nil;release?()
        modifiers=RecorderModifiers(heldKeys:[]);captureEscape=false
    }
    public func checkSession(){
        if cleanup != nil && (!core.active || !frontmost() || !trusted() || now()>=deadline){stop()}
    }
    public func process(type:CGEventType,event:CGEvent)->CGEvent? {
        checkSession()
        guard core.active else{return event}
        guard type == .keyDown || type == .keyUp || type == .flagsChanged else{return event}
        let key=UInt16(clamping:event.getIntegerValueField(.keyboardEventKeycode))
        if key==53 && type == .keyDown && !captureEscape {stop();return nil}
        let flags=NSEvent.ModifierFlags(rawValue:UInt(event.flags.rawValue))
        guard modifiers.update(keyCode:key,flags:flags,isFlagsChanged:type == .flagsChanged) else{stop();return nil}
        let time=Double(event.timestamp)/1_000_000_000
        core.synchronizeModifiers(modifiers.keys,time:time)
        if type != .flagsChanged && event.getIntegerValueField(.keyboardEventAutorepeat)==0,
           let code=MacKeycodes.qmk[key]{core.record(code:code,down:type == .keyDown,time:time)}
        if !core.active{stop()}
        return nil
    }
    private static func installCapture(_ owner:ShortcutRecorder)->(()->Void)? {
        // Secure input blocks other keyboard monitors, including our former CGEvent tap.
        guard let restore=RecordingInputProtection.acquire() else{return nil}
        guard let monitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.keyUp,.flagsChanged],handler:{[weak owner] event in
            let consumed=MainActor.assumeIsolated {
                guard let owner else{return false}
                guard let input=event.cgEvent else{owner.stop();return true}
                return owner.process(type:input.type,event:input)==nil
            }
            return consumed ? nil:event
        }) else{restore();return nil}
        return {NSEvent.removeMonitor(monitor);restore()}
    }
    isolated deinit {timer?.invalidate();cleanup?()}
}
public enum RecordingError:LocalizedError {
    case permissionRequired,captureUnavailable,keepInFront
    public var errorDescription:String? {
        switch self {
        case .permissionRequired:return "Allow KLAWOS Studio in System Settings → Privacy & Security → Accessibility, then click Record again. This pauses other shortcuts while you record."
        case .captureUnavailable:return "Recording could not start safely. Check KLAWOS Studio’s Accessibility permission, reopen Studio, and try again."
        case .keepInFront:return "Keep KLAWOS Studio in front while recording."
        }
    }
}
