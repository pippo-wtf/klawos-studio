import XCTest
@testable import KlawosContracts
final class KeyRoundTripTests: XCTestCase {
    func testWriteReadRestoreWithDurableIntentBeforeEachWrite() throws {
        var value: UInt16 = 4; var events: [String] = []
        let result = try KeyRoundTrip.run(expected: 4, temporary: 104, read: { events.append("read"); return value }, write: { events.append("write:\($0)"); value = $0 }, journal: { events.append($0) })
        XCTAssertEqual(result, .restored)
        XCTAssertEqual(value, 4)
        XCTAssertEqual(events, ["read", "apply-intent", "write:104", "read", "applied-verified", "read", "restore-intent", "write:4", "read", "restored-verified"])
    }
    func testJournalFailurePreventsWrite() {
        var writes = 0
        XCTAssertThrowsError(try KeyRoundTrip.run(expected: 4, temporary: 104, read: { 4 }, write: { _ in writes += 1 }, journal: { _ in throw CocoaError(.fileWriteNoPermission) }))
        XCTAssertEqual(writes, 0)
    }
    func testStaleCellPreventsWrite() {
        var writes = 0
        XCTAssertThrowsError(try KeyRoundTrip.run(expected: 4, temporary: 104, read: { 5 }, write: { _ in writes += 1 }, journal: { _ in }))
        XCTAssertEqual(writes, 0)
    }
    func testAmbiguousWriteIsReadBackThenRestoredWithoutRetry() throws {
        var value: UInt16 = 4; var writes: [UInt16] = []
        let result = try KeyRoundTrip.run(expected: 4, temporary: 104, read: { value }, write: { code in
            value = code; writes.append(code)
            if code == 104 { throw CocoaError(.fileReadUnknown) }
        }, journal: { _ in })
        XCTAssertEqual(result, .restored)
        XCTAssertEqual(writes, [104, 4])
    }
    func testDisconnectLeavesRecoveryStateAndDoesNotBlindlyWrite() throws {
        var disconnected = false; var writes = 0
        let result = try KeyRoundTrip.run(expected: 4, temporary: 104, read: {
            if disconnected { throw CocoaError(.fileReadUnknown) }; return 4
        }, write: { _ in writes += 1; disconnected = true }, journal: { _ in })
        XCTAssertEqual(result, .recoveryRequired)
        XCTAssertEqual(writes, 1)
    }
    func testUnexpectedExternalEditIsNotOverwritten() throws {
        var value: UInt16 = 4; var writes = 0
        let result = try KeyRoundTrip.run(expected: 4, temporary: 104, read: { value }, write: { _ in writes += 1; value = 5 }, journal: { _ in })
        XCTAssertEqual(result, .recoveryRequired)
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(value, 5)
    }
    func testPhysicalWindowRunsOnlyAfterVerifiedApplyAndRestoresAfterward() throws {
        var value: UInt16 = 4; var windowValue: UInt16?; var writes: [UInt16] = []
        let result = try KeyRoundTrip.run(expected: 4, temporary: 104, read: { value }, write: { value = $0; writes.append($0) }, journal: { _ in }, duringTemporary: { windowValue = value })
        XCTAssertEqual(windowValue, 104); XCTAssertEqual(value, 4)
        XCTAssertEqual(writes, [104, 4]); XCTAssertEqual(result, .restored)
    }
    func testLightingRecoveryGuardOnlyAcceptsOriginalBackedUpState() {
        XCTAssertNoThrow(try NarrowLightingRecoveryReport.validate(Data([7,0x41,3,0,63,216,93,71])))
        for packet: [UInt8] in [[7,0x41,3,0,63,208,93,71], [9], [7,0x41,3,0,63,216,93,255], [5,0,0,0,0,104]] {
            XCTAssertThrowsError(try NarrowLightingRecoveryReport.validate(Data(packet)))
        }
    }
    func testNarrowWriteGuardCannotAlterOtherKeysOrLayers() {
        XCTAssertNoThrow(try NarrowKeyTestReport.validate(Data([5,0,0,0,0,104])))
        XCTAssertNoThrow(try NarrowKeyTestReport.validate(Data([5,0,0,0,0,4])))
        for packet: [UInt8] in [[5,1,0,0,0,104], [5,0,0,1,0,104], [5,0,0,0,0,5], [7], [5,0,0,0,0,104,1]] {
            XCTAssertThrowsError(try NarrowKeyTestReport.validate(Data(packet)))
        }
        XCTAssertThrowsError(try ReadOnlyReport.validate(Data([5,0,0,0,0,104])))
    }
}
