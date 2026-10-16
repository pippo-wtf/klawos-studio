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
    func testApprovedExplicitOutputsAppearInPreviewAndRemainCollisionSources() throws {
        var s = snapshot()
        s.hardware["layout"] = .array([.array([.array([.string("KC_A")])]), .array([.array([.string("KC_1")])]), .array([.array([.string("KC_TRNS")])])])
        let outputs: [FieldPath: JSONValue] = ["hardware.layout.2.0.0": .string("KC_A")]
        let p = try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"], verifiedLayerOutputs: outputs)
        XCTAssertEqual(p.fieldEdits.map(\.path), ["hardware.layout.0.0.0", "hardware.layout.2.0.0"])
        XCTAssertEqual(p.fieldEdits.last?.value, .string("KC_A"))
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"], verifiedLayerOutputs: ["hardware.layout.2.0.0": .string("KC_TRNS")]))
        let occupied = try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"], verifiedLayerOutputs: ["hardware.layout.2.0.0": .string("KC_F13")])
        XCTAssertEqual(occupied.allocations["key:0:0"], "KC_F14")
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:0"], verifiedLayerOutputs: ["hardware.layout.1.0.0": .string("KC_B")]))
    }
    func testTransparentGamingLayersKeepTheirCurrentWorkOutput() throws {
        var base = snapshot()
        base.hardware["layout"] = .array([
            .array([.array([.string("KC_A"), .string("KC_B")])]),
            .array([.array([.string("KC_1"), .string("KC_TRNS")])]),
            .array([.array([.integer(1), .string("KC_TRNS")])]),
        ])
        let allocator = TriggerAllocator()
        let kept = try allocator.inheritedOutputs(base: base.hardware, proposed: base.hardware, helperInputs: ["key:0:0"])
        XCTAssertEqual(kept, ["hardware.layout.2.0.0": .string("KC_A")])
        let plan = try allocator.allocate(snapshot: base, helperInputs: ["key:0:0"], verifiedLayerOutputs: kept)
        XCTAssertEqual(plan.allocations, ["key:0:0": "KC_F13"])
        XCTAssertEqual(plan.fieldEdits, [FieldEdit(path: "hardware.layout.0.0.0", value: .string("KC_F13")),
                                         FieldEdit(path: "hardware.layout.2.0.0", value: .string("KC_A"))])
        // The output before this edit is kept, not the user's new Work value.
        var proposed = base.hardware
        proposed["layout"] = .array([
            .array([.array([.string("KC_A"), .string("KC_Z")])]),
            .array([.array([.string("KC_1"), .string("KC_TRNS")])]),
            .array([.array([.integer(1), .string("KC_TRNS")])]),
        ])
        XCTAssertEqual(try allocator.inheritedOutputs(base: base.hardware, proposed: proposed, helperInputs: ["key:0:1"]),
                       ["hardware.layout.1.0.1": .string("KC_B"), "hardware.layout.2.0.1": .string("KC_B")])
    }
    func testInheritedOutputsNeverPinATriggerOrInheritNothing() throws {
        var s = snapshot()
        s.hardware["layout"] = .array([.array([.array([.string("KC_F13"), .string("KC_TRNS")])]),
                                       .array([.array([.string("KC_TRNS"), .string("KC_TRNS")])])])
        XCTAssertThrowsError(try TriggerAllocator().inheritedOutputs(base: s.hardware, proposed: s.hardware, helperInputs: ["key:0:0"])) {
            XCTAssertEqual($0 as? TriggerAllocationError, .inheritedLayerConflict)
        }
        let kept = try TriggerAllocator().inheritedOutputs(base: s.hardware, proposed: s.hardware, helperInputs: ["key:0:1"])
        XCTAssertEqual(kept, ["hardware.layout.1.0.1": .string("KC_NO")])
        XCTAssertEqual(try TriggerAllocator().allocate(snapshot: s, helperInputs: ["key:0:1"], verifiedLayerOutputs: kept).allocations,
                       ["key:0:1": "KC_F14"])
    }
    func testRealBoardSpareLayersNoLongerBlockANewWorkAction() throws {
        // KLAWOS: Work, Dota and Wardogs switch with TO(); layers 3-5 are spare and mostly transparent.
        let spare: JSONValue = .array([.array([.string("KC_A"), .string("KC_TRNS"), .string("KC_TRNS"), .string("KC_TRNS")]),
                                       .array([.string("KC_TRNS"), .string("KC_TRNS"), .string("KC_TRNS"), .string("KC_TRNS")]),
                                       .array([.string("KC_TRNS"), .string("KC_TRNS"), .string("KC_TRNS"), .string("KC_F")]),
                                       .array([.string("KC_TRNS"), .string("KC_TRNS"), .string("KC_D"), .string("KC_T")])])
        var s = snapshot()
        s.hardware["layout"] = .array([
            .array([.array([.string("LCA(KC_D)"), .string("LCA(KC_F)"), .string("LCA(KC_G)"), .string("TO(1)")]),
                    .array([.string("KC_D"), .string("KC_E"), .string("KC_F"), .string("KC_G")]),
                    .array([.string("KC_Q"), .string("KC_W"), .string("LGUI(KC_B)"), .string("KC_F13")]),
                    .array([.string("KC_A"), .string("KC_S"), .string("KC_F15"), .string("KC_F14")])]),
            .array([.array([.string("KC_1"), .string("KC_2"), .string("KC_3"), .string("TO(2)")]),
                    .array([.string("KC_4"), .string("KC_5"), .string("KC_6"), .string("KC_8")]),
                    .array([.string("KC_A"), .string("KC_Q"), .string("KC_W"), .string("KC_E")]),
                    .array([.string("KC_S"), .string("KC_D"), .string("KC_F"), .string("KC_R")])]),
            .array((0..<4).map { row in .array((0..<4).map { .string(row == 0 && $0 == 3 ? "TO(0)" : "KC_NO") }) }),
            spare, spare, spare,
        ])
        let inputs = ["key:2:3", "key:3:3", "key:3:2", "key:1:0"]
        XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: s, helperInputs: inputs))
        let kept = try TriggerAllocator().inheritedOutputs(base: s.hardware, proposed: s.hardware, helperInputs: inputs)
        XCTAssertEqual(kept, ["hardware.layout.3.1.0": .string("KC_D"), "hardware.layout.4.1.0": .string("KC_D"),
                              "hardware.layout.5.1.0": .string("KC_D")])
        let plan = try TriggerAllocator().allocate(snapshot: s, helperInputs: inputs, verifiedLayerOutputs: kept)
        XCTAssertEqual(plan.allocations, ["key:2:3": "KC_F13", "key:3:3": "KC_F14", "key:3:2": "KC_F15", "key:1:0": "KC_F16"])
    }
    func testRejectInvalidOrDuplicateControlIDs() {
        for inputs in [["key:0:0", "key:0:0"], ["key:4:0"], ["key:-1:0"], ["encoder:0:cw"], ["key:0:3"]] {
            XCTAssertThrowsError(try TriggerAllocator().allocate(snapshot: snapshot(), helperInputs: inputs))
        }
    }
}
