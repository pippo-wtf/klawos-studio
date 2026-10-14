import XCTest
@testable import KlawosContracts

final class TriggerAllocatorTests: XCTestCase {
    private func snapshot() -> Snapshot {
        Snapshot(identity: DeviceIdentity(uid: "1", viaProtocol: 9, vialProtocol: 5, definitionHash: "test"), hardware: ["layout": .array([.array([.array([.string("KC_A"), .string("KC_B")])])])], lighting: [:], capabilities: [:], unreadableFields: [], metadata: [:], capturedAt: "", revision: "baseline")
    }
    func testOrderedAllocationProducesWorkOnlyEdits() throws {
        let p = try TriggerAllocator().allocate(snapshot: snapshot(), helperInputs: ["key:0:1", "key:0:0"])
        XCTAssertEqual(p.allocations, ["key:0:0": "KC_F13", "key:0:1": "KC_F14"])
        XCTAssertEqual(p.sourceRevision, "baseline")
        XCTAssertEqual(p.fieldEdits.map(\.path), ["hardware.layout.0.0.0", "hardware.layout.0.0.1"])
    }
    func testEveryEmissionRegionReservesEvenNestedOrModifiedCodes() throws {
        for field in ["encoder_layout", "macro", "tap_dance", "combo", "key_override", "alt_repeat_key"] {
            var s = snapshot()
            s.hardware[field] = .array([.object(["output": .array([.string("LSFT(KC_F13)"), .integer(105)])])])
            let p = try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"])
            XCTAssertEqual(p.allocations["key:0:0"], "KC_F15", field)
        }
    }
    func testGamingLayerCollisionAndNumericExpression() throws {
        var s = snapshot()
        s.hardware["layout"] = .array([.array([.array([.string("KC_A")])]), .array([.array([.integer(0x0168)])])])
        s.hardware["macro"] = .array([.string("(0x69)")])
        XCTAssertEqual(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]).allocations["key:0:0"], "KC_F15")
    }
    func testFailsClosedForUnreadableUnknownAndUnsupportedExpressions() {
        var s = snapshot(); s.unreadableFields = ["macro"]
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]))
        s = snapshot(); s.hardware["vendor_outputs"] = .array([])
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]))
        s = snapshot(); s.hardware["macro"] = .array([.string("100+4")])
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]))
    }
    func testExhaustionDoesNotSilentlyEnableModifiers() {
        var s = snapshot(); s.hardware["macro"] = .array((13...24).map { .string("KC_F\($0)") })
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]))
    }
    func testRealLayoutOptionsFieldAndUnprovenMacKeycodes() throws {
        var s = snapshot(); s.hardware["layout_options"] = .integer(0)
        XCTAssertEqual(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]).allocations["key:0:0"], "KC_F13")
        s.hardware["macro"] = .array((13...20).map { .string("KC_F\($0)") })
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]))
    }
    func testExistingReservationsStayStableWhenAddingEarlierControl() throws {
        var s = snapshot()
        s.hardware["layout"] = .array([.array([.array([.string("KC_A"), .string("KC_F13")])])])
        let plan = try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0", "key:0:1"])
        XCTAssertEqual(plan.allocations["key:0:1"], "KC_F13")
        XCTAssertEqual(plan.allocations["key:0:0"], "KC_F14")
        s.hardware["combo"] = .array([.string("KC_F13")])
        let conflict = try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:1"])
        XCTAssertEqual(conflict.allocations["key:0:1"], "KC_F14")
    }
    func testTransparentGamingInheritanceBlocksWorkOnlyAssignment() {
        for transparent in [JSONValue.string("KC_TRNS"), .string("KC_TRANSPARENT"), .string("_______"), .integer(1)] {
            var s = snapshot()
            s.hardware["layout"] = .array([.array([.array([.string("KC_A")])]), .array([.array([transparent])])])
            XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"]))
        }
    }
    func testRejectInvalidOrDuplicateControlIDs() {
        for inputs in [["key:0:0", "key:0:0"], ["key:4:0"], ["key:-1:0"], ["encoder:0:cw"], ["key:0:3"]] {
            XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: snapshot(), helperInputs: inputs))
        }
    }
}
