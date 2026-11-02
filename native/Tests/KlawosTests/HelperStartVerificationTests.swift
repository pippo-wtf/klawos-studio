import XCTest
@testable import KlawosContracts

final class HelperStartVerificationTests: XCTestCase {
    private func snapshot() -> Snapshot {
        Snapshot(identity: DeviceIdentity(uid: "1", viaProtocol: 9, vialProtocol: 5, definitionHash: "test"),
                 hardware: ["layout": .array([.array([.array([.string("KC_F13"), .string("KC_A")])])])],
                 lighting: [:], capabilities: [:], unreadableFields: [],
                 metadata: ["descriptor": .object(["pathToken": .string("123")])], capturedAt: "", revision: "fresh")
    }
    private func saved() -> SavedHelper {
        SavedHelper(configuration: HelperConfiguration(generation: UUID(), triggerMapRevision: "old",
                    bindings: ["key:0:0": [:]]), allocations: ["key:0:0": "KC_F13"], uid: "1", definitionHash: "test")
    }
    func testRevisionDriftStartsWithDurablyAdoptedRevision() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("helper.json")
        let original = saved()
        try DurableFile.write(JSONEncoder().encode(original), to: file)
        let verified = try original.verifiedForStart(snapshot: snapshot(), vialRunning: false)
        try verified.persistRevisionChange(from: original, to: file)
        let persisted = try JSONDecoder().decode(SavedHelper.self, from: Data(contentsOf: file))
        XCTAssertEqual(persisted.configuration.triggerMapRevision, "fresh")
        XCTAssertEqual(persisted.configuration.generation, original.configuration.generation)
        XCTAssertEqual(persisted.allocations, original.allocations)
        let router = InputRouter()
        try router.activate(allocations: persisted.allocations, configuration: persisted.configuration,
                            deviceGeneration: "123", verifiedRevision: snapshot().revision)
        XCTAssertTrue(router.isActive)
    }
    func testChangedKeysRefuseEvenWhenAllocatorWouldRecreateSameReservation() throws {
        var board = snapshot()
        board.hardware["layout"] = .array([.array([.array([.string("KC_B"), .string("KC_A")])])])
        XCTAssertEqual(try TriggerAllocator().allocate(snapshot: board, helperInputs: ["key:0:0"]).allocations, saved().allocations)
        assertRefusal(board, .keysChanged)
    }
    func testChangedAllocationsRefuse() {
        var board = snapshot(); board.hardware["macro"] = .array([.string("KC_F13")])
        assertRefusal(board, .keysChanged)
    }
    func testDifferentKeyboardRefuses() {
        var board = snapshot(); board.identity.uid = "2"
        assertRefusal(board, .differentKeyboard)
        board = snapshot(); board.identity.definitionHash = "different"
        assertRefusal(board, .differentKeyboard)
    }
    func testMissingDescriptorAndUnreadableBoardRefuse() {
        var board = snapshot(); board.metadata = [:]
        assertRefusal(board, .disconnected)
        board = snapshot(); board.unreadableFields = ["layout"]
        assertRefusal(board, .boardUnreadable)
    }
    func testVialRefuses() {
        XCTAssertThrowsError(try saved().verifiedForStart(snapshot: snapshot(), vialRunning: true)) {
            XCTAssertEqual($0 as? HelperStartError, .vialOpen)
        }
    }
    func testLegacyConfigurationWithoutDefinitionHashCanAdopt() throws {
        let original = saved()
        let legacy = SavedHelper(configuration: original.configuration, allocations: original.allocations, uid: original.uid, definitionHash: nil)
        XCTAssertEqual(try legacy.verifiedForStart(snapshot: snapshot(), vialRunning: false).configuration.triggerMapRevision, "fresh")
    }
    func testKeysChangedReasonIsActionable() {
        XCTAssertEqual(HelperStartError.keysChanged.reason, "Mac-action keys were changed on the keyboard. Re-save your keys in Studio.")
    }
    @MainActor func testStartRefusalPublishesReasonAndInvalidatesPendingActions() {
        let capture = LiveInputCapture()
        let previous = capture.executionGeneration
        capture.failStart(reason: HelperStartError.keysChanged.reason)
        XCTAssertEqual(capture.reason, HelperStartError.keysChanged.reason)
        XCTAssertFalse(capture.active)
        XCTAssertNotEqual(capture.executionGeneration, previous)
    }
    func testPersistenceFailureRefusesWithSaveReason() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let verified = try saved().verifiedForStart(snapshot: snapshot(), vialRunning: false)
        XCTAssertThrowsError(try verified.persistRevisionChange(from: saved(), to: directory)) {
            XCTAssertEqual($0 as? HelperStartError, .saveFailed)
        }
    }
    func testPermissionAndConnectionErrorsHaveSpecificReasons() {
        XCTAssertEqual(HelperStartError.reason(for: InputTapError.disconnected), HelperStartError.disconnected.reason)
        XCTAssertEqual(HelperStartError.reason(for: InputTapError.permissionRequired),
                       "Allow KLAWOS Helper in Accessibility and Input Monitoring in System Settings.")
    }
    private func assertRefusal(_ board: Snapshot, _ expected: HelperStartError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try saved().verifiedForStart(snapshot: board, vialRunning: false), file: file, line: line) {
            XCTAssertEqual($0 as? HelperStartError, expected, file: file, line: line)
        }
    }
}
