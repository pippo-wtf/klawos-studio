import AppKit
import Carbon

/// Explicit foreground recording: temporarily suspends hotkeys and consumes key events.
@MainActor public final class ShortcutRecorder {
    public let core=MacroRecorderCore()
    private var modifiers=RecorderModifiers(heldKeys:[])
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
        install:Self.installFilter)}
    init(trusted:@escaping ()->Bool,frontmost:@escaping ()->Bool,now:@escaping ()->TimeInterval,
         held:@escaping ()->Set<UInt16>,install:@escaping (ShortcutRecorder)->(()->Void)?){
        self.trusted=trusted;self.frontmost=frontmost;self.now=now;self.held=held;self.install=install
    }
    public func start() throws {
        stop()
        guard frontmost() else{throw RecordingError.keepInFront}
        guard trusted() else{throw RecordingError.permissionRequired}
        guard let cleanup=install(self) else{throw RecordingError.captureUnavailable}
        self.cleanup=cleanup
        modifiers=RecorderModifiers(heldKeys:held());deadline=now()+35
        core.start(heldModifiers:modifiers.keys,time:now())
        timer=Timer.scheduledTimer(withTimeInterval:0.25,repeats:true){[weak self] _ in
            MainActor.assumeIsolated{self?.checkSession()}
        }
    }
    public func stop(){
        core.stop();timer?.invalidate();timer=nil
        let release=cleanup;cleanup=nil;release?()
        modifiers=RecorderModifiers(heldKeys:[])
    }
    public func checkSession(){
        if cleanup != nil && (!core.active || !frontmost() || !trusted() || now()>=deadline){stop()}
    }
    public func process(type:CGEventType,event:CGEvent)->CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {stop();return event}
        checkSession()
        guard core.active else{return event}
        guard type == .keyDown || type == .keyUp || type == .flagsChanged else{return event}
        let key=UInt16(clamping:event.getIntegerValueField(.keyboardEventKeycode))
        if key==53 && type == .keyDown {stop();return nil}
        let flags=NSEvent.ModifierFlags(rawValue:UInt(event.flags.rawValue))
        guard modifiers.update(keyCode:key,flags:flags,isFlagsChanged:type == .flagsChanged) else{stop();return nil}
        let time=Double(event.timestamp)/1_000_000_000
        core.synchronizeModifiers(modifiers.keys,time:time)
        if type != .flagsChanged && event.getIntegerValueField(.keyboardEventAutorepeat)==0,
           let code=MacKeycodes.qmk[key]{core.record(code:code,down:type == .keyDown,time:time)}
        if !core.active{stop()}
        return nil
    }
    private static func installFilter(_ owner:ShortcutRecorder)->(()->Void)? {
        // A local NSEvent monitor runs too late for another app's registered hotkeys.
        guard let token=PushSymbolicHotKeyMode(OptionBits(kHIHotKeyModeAllDisabled)) else{return nil}
        let mask=[CGEventType.keyDown,.keyUp,.flagsChanged].reduce(CGEventMask(0)){$0 | (1 << $1.rawValue)}
        let context=Unmanaged.passUnretained(owner).toOpaque()
        guard let tap=CGEvent.tapCreate(tap:.cgSessionEventTap,place:.headInsertEventTap,options:.defaultTap,
            eventsOfInterest:mask,callback:{_,type,event,context in
                guard let context else{return Unmanaged.passUnretained(event)}
                let consumed=MainActor.assumeIsolated{
                    let owner=Unmanaged<ShortcutRecorder>.fromOpaque(context).takeUnretainedValue()
                    return owner.process(type:type,event:event)==nil
                }
                return consumed ? nil:Unmanaged.passUnretained(event)
            },userInfo:context) else{PopSymbolicHotKeyMode(token);return nil}
        guard let source=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,tap,0) else{
            CFMachPortInvalidate(tap);PopSymbolicHotKeyMode(token);return nil
        }
        CFRunLoopAddSource(CFRunLoopGetMain(),source,.commonModes)
        CGEvent.tapEnable(tap:tap,enable:true)
        guard CGEvent.tapIsEnabled(tap:tap) else{
            CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes)
            CFMachPortInvalidate(tap);PopSymbolicHotKeyMode(token);return nil
        }
        return {
            CGEvent.tapEnable(tap:tap,enable:false);CFMachPortInvalidate(tap)
            CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes)
            PopSymbolicHotKeyMode(token)
        }
    }
    isolated deinit {timer?.invalidate();cleanup?()}
}
public enum RecordingError:LocalizedError {
    case permissionRequired,captureUnavailable,keepInFront
    public var errorDescription:String? {
        switch self {
        case .permissionRequired:return "Allow KLAWOS Studio in System Settings → Privacy & Security → Accessibility, then click Record again. This pauses other shortcuts while you record."
        case .captureUnavailable:return "Recording could not start. Check KLAWOS Studio’s Accessibility permission, reopen Studio, and try again."
        case .keepInFront:return "Keep KLAWOS Studio in front while recording."
        }
    }
}
