import Foundation
import CoreGraphics

public enum MacInputEvent {
    /// Applied to every event posted by this helper, including release cleanup.
    public static let syntheticMarker: Int64 = 0x4b4c41574f53
    private static let functionKeys: [Int64: Int] = [105:13, 107:14, 113:15, 106:16, 64:17, 79:18, 80:19, 90:20]

    /// Inspect only candidate function keys; never extract text from events.
    public static func decode(_ event: CGEvent, type: CGEventType) -> InputSample? {
        guard type == .keyDown || type == .keyUp else { return nil }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        guard let function = functionKeys[code] else { return nil }
        let modifiers = event.flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        let chord = modifiers.isEmpty ? "KC_F\(function)" : "modified:\(modifiers.rawValue):KC_F\(function)"
        let synthetic = event.getIntegerValueField(.eventSourceUserData) == syntheticMarker ||
            event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(ProcessInfo.processInfo.processIdentifier)
        return InputSample(sourceID: "global-event-stream", input: chord,
                           phase: type == .keyDown ? "down" : "up", synthetic: synthetic,
                           timestamp: event.timestamp, keyCode: UInt16(code))
    }
}
