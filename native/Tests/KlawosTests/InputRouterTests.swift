import XCTest
@testable import KlawosContracts

final class InputRouterTests: XCTestCase {
    private func config() -> HelperConfiguration {
        HelperConfiguration(generation: UUID(), triggerMapRevision: "verified", bindings: ["key:0:0": [:]])
    }
    private func sample(_ chord: String = "KC_F13", phase: String = "down", source: String = "keyboard", synthetic: Bool = false, key: UInt16 = 105) -> InputSample {
        InputSample(sourceID: source, input: chord, phase: phase, synthetic: synthetic, timestamp: 1, keyCode: key)
    }
    private func start(_ router: InputRouter, _ config: HelperConfiguration) throws {
        try router.activate(allocations: ["key:0:0": "KC_F13"], configuration: config, deviceGeneration: "connection-1", verifiedRevision: "verified")
    }
    func testGlobalReservationAndUnrelatedInput() throws {
        let router = InputRouter(); let c = config(); try start(router, c)
        XCTAssertEqual(router.route(sample(source: "ordinary-keyboard"), configuration: c), .helperPress("key:0:0"))
        XCTAssertEqual(router.route(sample(phase: "up", source: "ordinary-keyboard"), configuration: c), .helperRelease("key:0:0"))
        XCTAssertEqual(router.route(sample("KC_A", key: 0), configuration: c), .passThrough)
        XCTAssertEqual(router.route(sample("KC_LSFT", phase: "flags", key: 56), configuration: c), .passThrough)
    }
    func testRepeatDoesNotDispatchAgainAndReleaseUsesKeyNotCurrentModifiers() throws {
        let router = InputRouter(); let c = config(); try start(router, c)
        XCTAssertEqual(router.route(sample(), configuration: c), .helperPress("key:0:0"))
        XCTAssertEqual(router.route(sample(), configuration: c), .consumed)
        XCTAssertEqual(router.route(sample("LSFT(KC_F13)", phase: "up"), configuration: c), .helperRelease("key:0:0"))
        XCTAssertEqual(router.route(sample(phase: "up"), configuration: c), .passThrough)
    }
    func testSyntheticDoesNotChangeHeldState() throws {
        let router = InputRouter(); let c = config(); try start(router, c)
        XCTAssertEqual(router.route(sample(synthetic: true), configuration: c), .ignoredSynthetic)
        XCTAssertEqual(router.route(sample(), configuration: c), .helperPress("key:0:0"))
        XCTAssertEqual(router.route(sample(phase: "up", synthetic: true), configuration: c), .ignoredSynthetic)
        XCTAssertEqual(router.releaseAll(reason: .stop), ["key:0:0"])
        XCTAssertEqual(router.route(sample(), configuration: c), .passThrough)
    }
    func testGenerationChangeRequiresReleaseBeforeReactivation() throws {
        let router = InputRouter(); let c = config(); try start(router, c)
        _ = router.route(sample(), configuration: c)
        XCTAssertThrowsError(try start(router, c))
        XCTAssertEqual(router.releaseAll(reason: .generationChanged), ["key:0:0"])
        try start(router, c)
        var changed = c; changed.generation = UUID()
        XCTAssertEqual(router.route(sample(), configuration: changed), .passThrough)
        XCTAssertFalse(router.isActive)
    }
    func testRejectUnverifiedOrAmbiguousReservations() {
        let router = InputRouter(); let c = config()
        XCTAssertThrowsError(try router.activate(allocations: ["key:0:0": "KC_F13"], configuration: c, deviceGeneration: "1", verifiedRevision: "wrong"))
        XCTAssertThrowsError(try router.activate(allocations: ["key:0:0": "KC_A"], configuration: c, deviceGeneration: "1", verifiedRevision: "verified"))
        XCTAssertThrowsError(try router.activate(allocations: ["key:0:0": "LSFT(KC_F13)"], configuration: c, deviceGeneration: "1", verifiedRevision: "verified"))
        XCTAssertFalse(router.isActive)
    }
    func testDriftDuringHoldQueuesCleanupAndStopsReservations() throws {
        let router = InputRouter(); let c = config(); try start(router, c)
        _ = router.route(sample(), configuration: c)
        var changed = c; changed.triggerMapRevision = "drift"
        XCTAssertEqual(router.route(sample(phase: "up"), configuration: changed), .passThrough)
        XCTAssertEqual(router.takePendingReleases(), ["key:0:0"])
        XCTAssertEqual(router.takePendingReleases(), [])
        XCTAssertFalse(router.isActive)
    }
}
