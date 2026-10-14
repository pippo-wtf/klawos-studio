import XCTest
import CoreGraphics
@testable import KlawosContracts

final class InputTapTests: XCTestCase {
    func testLifecycleAndSuppressionWithoutInstallingTap() throws {
        var connected = true
        let capture = InputTapController(deviceGeneration: "test", connected: { connected })
        try capture.prepareForTest()
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 105, keyDown: true)!
        key.setIntegerValueField(.eventSourceUnixProcessID, value: 0); key.flags = []
        XCTAssertNil(capture.process(type: .keyDown, event: key))
        XCTAssertNil(capture.process(type: .keyDown, event: key))
        XCTAssertEqual(capture.pressCount, 1)
        let ordinary = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        XCTAssertNotNil(capture.process(type: .keyDown, event: ordinary))
        connected = false
        capture.checkConnection()
        XCTAssertFalse(capture.isActive)
        XCTAssertNotNil(capture.process(type: .keyDown, event: key))
        XCTAssertEqual(capture.cleanupCount, 1)
    }
    func testDisabledTapStopsRatherThanSilentlyResuming() throws {
        let capture = InputTapController(deviceGeneration: "test", connected: { true })
        try capture.prepareForTest()
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 105, keyDown: true)!
        _ = capture.process(type: .tapDisabledByTimeout, event: event)
        XCTAssertFalse(capture.isActive)
        XCTAssertEqual(capture.stopReason, "tap-disabled")
    }
    func testDisconnectedDeviceCannotActivate() {
        let capture = InputTapController(deviceGeneration: "test", connected: { false })
        XCTAssertThrowsError(try capture.prepareForTest())
    }
    func testSyntheticInputPassesThroughWithoutDispatch() throws {
        let capture = InputTapController(deviceGeneration: "test", connected: { true })
        try capture.prepareForTest()
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 105, keyDown: true)!
        event.setIntegerValueField(.eventSourceUserData, value: MacInputEvent.syntheticMarker)
        XCTAssertNotNil(capture.process(type: .keyDown, event: event))
        XCTAssertEqual(capture.pressCount, 0)
    }
}
