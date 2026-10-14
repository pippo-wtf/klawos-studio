import XCTest
import CoreGraphics
@testable import KlawosContracts

final class MacInputEventTests: XCTestCase {
    private func event(_ key: CGKeyCode = 105, down: Bool = true) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)!
        event.setIntegerValueField(.eventSourceUnixProcessID, value: 0)
        event.flags = []
        return event
    }
    func testKnownMacFunctionKeys() {
        for (key, f) in [(105,13),(107,14),(113,15),(106,16),(64,17),(79,18),(80,19),(90,20)] {
            let sample = MacInputEvent.decode(event(CGKeyCode(key)), type: .keyDown)
            XCTAssertEqual(sample?.input, "KC_F\(f)")
            XCTAssertEqual(sample?.keyCode, UInt16(key))
            XCTAssertEqual(sample?.phase, "down")
        }
    }
    func testModifiersPreventBareChordMatchButReleaseKeepsKeyIdentity() {
        let e = event(down: false); e.flags = [.maskShift, .maskControl]
        let s = MacInputEvent.decode(e, type: .keyUp)
        XCTAssertNotEqual(s?.input, "KC_F13")
        XCTAssertEqual(s?.keyCode, 105)
        XCTAssertEqual(s?.phase, "up")
    }
    func testOwnSyntheticMarkerIsExcluded() {
        let e = event(); e.setIntegerValueField(.eventSourceUserData, value: MacInputEvent.syntheticMarker)
        XCTAssertTrue(MacInputEvent.decode(e, type: .keyDown)?.synthetic == true)
    }
    func testOrdinaryKeysAndModifierOnlyEventsAreNotSamples() {
        XCTAssertNil(MacInputEvent.decode(event(0), type: .keyDown))
        XCTAssertNil(MacInputEvent.decode(event(56), type: .flagsChanged))
    }
    func testCapsLockDoesNotChangeFunctionChord() {
        let e = event(); e.flags = [.maskAlphaShift]
        XCTAssertEqual(MacInputEvent.decode(e, type: .keyDown)?.input, "KC_F13")
    }
}
