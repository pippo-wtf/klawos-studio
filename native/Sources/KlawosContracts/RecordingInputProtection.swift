import Carbon

/// Owns one secure-input reference and one hotkey-mode token for explicit recording.
@MainActor enum RecordingInputProtection {
    static func acquire(enable:()->OSStatus={EnableSecureEventInput()},
                        disable:@escaping ()->OSStatus={DisableSecureEventInput()},
                        pause:()->UnsafeMutableRawPointer?={PushSymbolicHotKeyMode(OptionBits(kHIHotKeyModeAllDisabled))},
                        resume:@escaping (UnsafeMutableRawPointer)->Void={PopSymbolicHotKeyMode($0)})->(()->Void)? {
        guard enable()==noErr else{return nil}
        guard let token=pause() else{_=disable();return nil}
        return {resume(token);_=disable()}
    }
}
