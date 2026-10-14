import XCTest
@testable import KlawosContracts

final class CloudSettingsSyncTests: XCTestCase {
    private let uid = "6994672159869375106"
    private let definition = String(repeating: "a", count: 64)

    private func roots() throws -> (URL, URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("CloudDocs")
        let first = root.appendingPathComponent("first")
        let second = root.appendingPathComponent("second")
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (cloud, first, second)
    }

    func testTwoMacsExchangeSettingsWithoutWritingDeviceData() throws {
        let (cloud, first, second) = try roots()
        let macA = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let macB = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        let action: ContextBindings = ["default": .object(["kind": .string("openApp"),
                                                           "parameters": .object(["bundleID": .string("com.apple.TextEdit")])]),
                                       "overrides": .object([:])]
        let original = SharedSettings(profiles: ["key:0:0": action],
                                      layerNames: ["Work", "Dota", "Wardogs", "Edit"])
        guard case .current = try macA.publish(uid: uid, definitionHash: definition, settings: original) else {
            return XCTFail("First Mac should publish")
        }
        guard case .incoming(let imported) = macB.inspect(uid: uid, definitionHash: definition,
                                                           local: SharedSettings(profiles: [:], layerNames: [])) else {
            return XCTFail("Second Mac should receive settings")
        }
        XCTAssertEqual(imported.settings, original)
        try macB.markApplied(imported)
        let edited = SharedSettings(profiles: [:], layerNames: ["Work", "Dota", "Wardogs", "Design"])
        guard case .current = try macB.publish(uid: uid, definitionHash: definition, settings: edited) else {
            return XCTFail("Second Mac should publish its edit")
        }
        guard case .incoming(let returned) = macA.inspect(uid: uid, definitionHash: definition, local: original) else {
            return XCTFail("First Mac should receive the edit")
        }
        XCTAssertEqual(returned.settings, edited)
    }

    func testSimultaneousEditsPauseInsteadOfReplacingOneAnother() throws {
        let (cloud, first, second) = try roots()
        let macA = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let macB = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        let base = SharedSettings(profiles: [:], layerNames: ["Work"])
        _ = try macA.publish(uid: uid, definitionHash: definition, settings: base)
        guard case .incoming(let revision) = macB.inspect(uid: uid, definitionHash: definition,
                                                           local: SharedSettings(profiles: [:], layerNames: [])) else {
            return XCTFail("Initial import missing")
        }
        try macB.markApplied(revision)
        _ = try macA.publish(uid: uid, definitionHash: definition,
                             settings: SharedSettings(profiles: [:], layerNames: ["Work A"]))
        guard case .conflict = try macB.publish(uid: uid, definitionHash: definition,
                                                settings: SharedSettings(profiles: [:], layerNames: ["Work B"])) else {
            return XCTFail("Concurrent edit should pause")
        }
        XCTAssertEqual(macB.localSettings, base)
    }

    func testForeignOrMissingCloudStorageNeverOverwritesLocalSettings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let sync = try CloudSettingsSync(cloudRoot: root.appendingPathComponent("absent"),
                                         localRoot: root.appendingPathComponent("local"))
        let local = SharedSettings(profiles: [:], layerNames: ["Private"])
        guard case .unavailable = try sync.publish(uid: uid, definitionHash: definition, settings: local) else {
            return XCTFail("Missing iCloud Drive should be reported")
        }
        XCTAssertNil(sync.localSettings)
        guard case .unavailable = sync.inspect(uid: uid, definitionHash: definition, local: local) else {
            return XCTFail("Missing iCloud Drive should not import")
        }
    }

    func testOfflineBranchesBecomeVisibleConflictAndCanBeResolved() throws {
        let (cloud, first, _) = try roots()
        let macA = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let mine = SharedSettings(profiles: [:], layerNames: ["Work A"])
        _ = try macA.publish(uid: uid, definitionHash: definition, settings: mine)
        let folder = cloud.appendingPathComponent("KLAWOS Studio/Settings/\(uid)-\(definition)")
        let other = SyncRevision(formatVersion: 1, id: UUID(), parents: [], writer: UUID(),
                                 uid: uid, definitionHash: definition,
                                 settings: SharedSettings(profiles: [:], layerNames: ["Work B"]))
        try JSONEncoder().encode(other).write(to: folder.appendingPathComponent(other.id.uuidString + ".json"))
        guard case .conflict = macA.inspect(uid: uid, definitionHash: definition, local: mine) else {
            return XCTFail("Both offline branches should be visible")
        }
        XCTAssertEqual(try macA.otherMacConflict(uid: uid, definitionHash: definition)?.settings.layerNames, ["Work B"])
        guard case .current = try macA.resolveConflict(uid: uid, definitionHash: definition, settings: mine) else {
            return XCTFail("Resolution should join both branches")
        }
        guard case .current = macA.inspect(uid: uid, definitionHash: definition, local: mine) else {
            return XCTFail("Resolved settings should be current")
        }
    }
}
