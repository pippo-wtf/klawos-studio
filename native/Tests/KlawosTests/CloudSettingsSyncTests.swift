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

    func testWaitingNameChangeSurvivesRestartAndClearsOnlyAfterDelivery() throws {
        let (cloud, first, _) = try roots()
        let sync = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let original = SharedSettings(profiles: [:], layerNames: ["Work"])
        _ = try sync.publish(uid: uid, definitionHash: definition,
                             settings: SharedSettings(profiles: [:], layerNames: ["Initial"]))
        let parentID = sync.appliedRevision!
        _ = try sync.publish(uid: uid, definitionHash: definition, settings: original)
        let folder = cloud.appendingPathComponent("KLAWOS Studio/Settings/\(uid)-\(definition)")
        let parentFile = folder.appendingPathComponent(parentID.uuidString + ".json")
        let parentBytes = try Data(contentsOf: parentFile)
        try FileManager.default.removeItem(at: parentFile)
        let renamed = SharedSettings(profiles: [:], layerNames: ["Design"])
        guard case .waiting = try sync.publish(uid: uid, definitionHash: definition, settings: renamed) else {
            return XCTFail("Partial history must wait")
        }
        let restarted = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        XCTAssertEqual(restarted.pendingSettings, renamed)
        XCTAssertEqual(restarted.localSettings, original)
        try parentBytes.write(to: parentFile)
        guard case .current = restarted.inspect(uid: uid, definitionHash: definition, local: renamed),
              case .current = try restarted.publish(uid: uid, definitionHash: definition, settings: renamed) else {
            return XCTFail("Saved rename should retry automatically when history finishes downloading")
        }
        XCTAssertNil(restarted.pendingSettings)
        XCTAssertEqual(try CloudSettingsSync(cloudRoot: cloud, localRoot: first).localSettings, renamed)
    }

    func testOfflineDeletionSurvivesRestartAndPublishesEmptySettings() throws {
        let (cloud, first, _) = try roots()
        let sync = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let original = SharedSettings(profiles: [:], layerNames: ["Work"])
        _ = try sync.publish(uid: uid, definitionHash: definition, settings: original)
        let parked = cloud.appendingPathExtension("offline")
        try FileManager.default.moveItem(at: cloud, to: parked)
        let empty = SharedSettings(profiles: [:], layerNames: [])
        guard case .unavailable = try sync.publish(uid: uid, definitionHash: definition, settings: empty) else {
            return XCTFail("Offline cloud must pause")
        }
        let restarted = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        XCTAssertEqual(restarted.pendingSettings, empty)
        try FileManager.default.moveItem(at: parked, to: cloud)
        guard case .current = restarted.inspect(uid: uid, definitionHash: definition, local: empty),
              case .current = try restarted.publish(uid: uid, definitionHash: definition, settings: empty) else {
            return XCTFail("Deleting saved settings must retry without a false conflict")
        }
        XCTAssertNil(restarted.pendingSettings)
        XCTAssertEqual(restarted.localSettings, empty)
    }

    func testExplicitOtherMacChoiceClearsConflictingPendingNames() throws {
        let (cloud, first, second) = try roots()
        let a = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let b = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        let base = SharedSettings(profiles: [:], layerNames: ["Work"])
        _ = try a.publish(uid: uid, definitionHash: definition, settings: base)
        guard case .incoming(let initial) = b.inspect(uid: uid, definitionHash: definition,
                                                      local: SharedSettings(profiles: [:], layerNames: [])) else {
            return XCTFail("Initial settings missing")
        }
        try b.markApplied(initial)
        let theirs = SharedSettings(profiles: [:], layerNames: ["Other Mac"])
        _ = try a.publish(uid: uid, definitionHash: definition, settings: theirs)
        let mine = SharedSettings(profiles: [:], layerNames: ["This Mac"])
        _ = try b.publish(uid: uid, definitionHash: definition, settings: mine)
        XCTAssertEqual(b.pendingSettings, mine)
        try b.markApplied(initial)
        XCTAssertEqual(b.pendingSettings, mine, "Routine adoption cannot erase a different queued edit")
        _ = try b.resolveConflict(uid: uid, definitionHash: definition, settings: theirs)
        XCTAssertNil(b.pendingSettings)
        XCTAssertEqual(b.localSettings, theirs)
    }

    func testUnchangedPendingSaveDoesNotRepublishOldNamesAfterIncomingUpdate() throws {
        let (cloud, first, second) = try roots()
        let a = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let b = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        let base = SharedSettings(profiles: [:], layerNames: ["Work"])
        _ = try a.publish(uid: uid, definitionHash: definition, settings: base)
        guard case .incoming(let initial) = b.inspect(uid: uid, definitionHash: definition,
                                                      local: SharedSettings(profiles: [:], layerNames: [])) else {
            return XCTFail("Initial settings missing")
        }
        try b.markApplied(initial)
        let parked = cloud.appendingPathExtension("offline")
        try FileManager.default.moveItem(at: cloud, to: parked)
        _ = try b.publish(uid: uid, definitionHash: definition, settings: base)
        XCTAssertEqual(b.pendingSettings, base)
        try FileManager.default.moveItem(at: parked, to: cloud)
        let renamed = SharedSettings(profiles: [:], layerNames: ["Design"])
        _ = try a.publish(uid: uid, definitionHash: definition, settings: renamed)
        guard case .incoming(let incoming) = b.inspect(uid: uid, definitionHash: definition, local: base) else {
            return XCTFail("An unchanged saved snapshot must accept the other Mac's edit")
        }
        try b.markApplied(incoming)
        XCTAssertNil(b.pendingSettings, "An unchanged queued snapshot must not undo incoming names")
        XCTAssertEqual(b.localSettings, renamed)
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
    func testSingleHeadConflictKeepThisMacPublishesAndPersistsChoice() throws {
        try resolveSingleHeadConflict(useOther: false)
    }

    func testSingleHeadConflictUseOtherMacAdoptsAndPersistsChoice() throws {
        try resolveSingleHeadConflict(useOther: true)
    }

    private func resolveSingleHeadConflict(useOther: Bool) throws {
        let (cloud, first, second) = try roots()
        let macA = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let macB = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        let base = SharedSettings(profiles: [:], layerNames: ["Work"])
        let mine = SharedSettings(profiles: [:], layerNames: ["Work B"])
        let theirs = SharedSettings(profiles: [:], layerNames: ["Work A"])
        _ = try macA.publish(uid: uid, definitionHash: definition, settings: base)
        guard case .incoming(let revision) = macB.inspect(uid: uid, definitionHash: definition,
                                                         local: SharedSettings(profiles: [:], layerNames: [])) else {
            return XCTFail("Initial import missing")
        }
        try macB.markApplied(revision)
        _ = try macA.publish(uid: uid, definitionHash: definition, settings: theirs)
        guard case .conflict = try macB.publish(uid: uid, definitionHash: definition, settings: mine) else {
            return XCTFail("Divergent local edit must conflict")
        }
        let chosen: SharedSettings
        if useOther {
            let other = try XCTUnwrap(macB.otherMacConflict(uid: uid, definitionHash: definition))
            XCTAssertEqual(other.settings, theirs)
            chosen = other.settings
        } else { chosen = mine }
        guard case .current = try macB.resolveConflict(uid: uid, definitionHash: definition, settings: chosen) else {
            return XCTFail("Choice should resolve conflict")
        }
        XCTAssertEqual(macB.localSettings, chosen)
        guard case .current = macB.inspect(uid: uid, definitionHash: definition, local: chosen) else {
            return XCTFail("Resolution must remain current")
        }
        let restarted = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        XCTAssertEqual(restarted.localSettings, chosen)
        XCTAssertEqual(restarted.appliedRevision, macB.appliedRevision)
        if !useOther {
            guard case .incoming(let published) = macA.inspect(uid: uid, definitionHash: definition, local: theirs) else {
                return XCTFail("Other Mac must receive the local choice")
            }
            XCTAssertEqual(published.settings, mine)
        }
    }

    func testSavedLocalChangesCanPublishAfterRestartWhenCloudHeadIsUnchanged() throws {
        let (cloud, first, second) = try roots()
        let initial = SharedSettings(profiles: [:], layerNames: ["Work"])
        let changed = SharedSettings(profiles: [:], layerNames: ["Work", "Dota", "Wardogs", "Editing"])
        let original = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        _ = try original.publish(uid: uid, definitionHash: definition, settings: initial)
        let restarted = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        guard case .current = restarted.inspect(uid: uid, definitionHash: definition, local: changed) else {
            return XCTFail("A saved local edit is not a two-Mac conflict when the cloud head is unchanged")
        }
        guard case .current = try restarted.publish(uid: uid, definitionHash: definition, settings: changed) else {
            return XCTFail("Local changes must be retried automatically")
        }
        let other = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        guard case .incoming(let revision) = other.inspect(uid: uid, definitionHash: definition,
                                                         local: SharedSettings(profiles: [:], layerNames: [])) else {
            return XCTFail("A fresh Mac should receive the latest saved settings")
        }
        XCTAssertEqual(revision.settings, changed)
    }

    func testMissingHistoryWaitsWithoutPublishingAndRecoversWhenParentArrives() throws {
        let (cloud, first, second) = try roots()
        let original = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let base = SharedSettings(profiles: [:], layerNames: ["Work"])
        let updated = SharedSettings(profiles: [:], layerNames: ["Work", "Dota"])
        _ = try original.publish(uid: uid, definitionHash: definition, settings: base)
        let parentID = try XCTUnwrap(original.appliedRevision)
        _ = try original.publish(uid: uid, definitionHash: definition, settings: updated)
        let folder = cloud.appendingPathComponent("KLAWOS Studio/Settings/\(uid)-\(definition)")
        let parent = folder.appendingPathComponent(parentID.uuidString + ".json")
        let bytes = try Data(contentsOf: parent)
        try FileManager.default.removeItem(at: parent)
        let other = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        let empty = SharedSettings(profiles: [:], layerNames: [])
        XCTAssertEqual(String(describing: other.inspect(uid: uid, definitionHash: definition, local: empty)), "waiting")
        XCTAssertEqual(String(describing: try other.publish(uid: uid, definitionHash: definition, settings: base)), "waiting")
        XCTAssertNil(other.appliedRevision)
        XCTAssertNil(other.localSettings)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 1)
        try bytes.write(to: parent)
        guard case .incoming(let revision) = other.inspect(uid: uid, definitionHash: definition, local: empty) else {
            return XCTFail("Sync should retry successfully when history arrives")
        }
        XCTAssertEqual(revision.settings, updated)
    }

    func testChangedAppliedRevisionContentsStayInvalidInsteadOfBeingOverwritten() throws {
        let (cloud, first, _) = try roots()
        let sync = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let original = SharedSettings(profiles: [:], layerNames: ["Work"])
        _ = try sync.publish(uid: uid, definitionHash: definition, settings: original)
        let id = try XCTUnwrap(sync.appliedRevision)
        let file = cloud.appendingPathComponent("KLAWOS Studio/Settings/\(uid)-\(definition)/\(id.uuidString).json")
        var revision = try JSONDecoder().decode(SyncRevision.self, from: Data(contentsOf: file))
        revision.settings = SharedSettings(profiles: [:], layerNames: ["Changed in place"])
        try JSONEncoder().encode(revision).write(to: file)
        guard case .invalid = sync.inspect(uid: uid, definitionHash: definition, local: original) else {
            return XCTFail("An immutable revision changing in place is invalid")
        }
        XCTAssertEqual(sync.localSettings, original)
    }

    func testLocalAndOtherMacChangesStillConflictDuringAutomaticInspection() throws {
        let (cloud, first, second) = try roots()
        let a = try CloudSettingsSync(cloudRoot: cloud, localRoot: first)
        let b = try CloudSettingsSync(cloudRoot: cloud, localRoot: second)
        let base = SharedSettings(profiles: [:], layerNames: ["Work"])
        _ = try a.publish(uid: uid, definitionHash: definition, settings: base)
        guard case .incoming(let initial) = b.inspect(uid: uid, definitionHash: definition,
                                                     local: SharedSettings(profiles: [:], layerNames: [])) else {
            return XCTFail("Initial settings missing")
        }
        try b.markApplied(initial)
        _ = try a.publish(uid: uid, definitionHash: definition,
                          settings: SharedSettings(profiles: [:], layerNames: ["Other Mac"]))
        guard case .conflict = b.inspect(uid: uid, definitionHash: definition,
                                         local: SharedSettings(profiles: [:], layerNames: ["This Mac"])) else {
            return XCTFail("Actual edits on both Macs must still pause")
        }
        XCTAssertEqual(b.localSettings, base)
    }

    func testCloudRevisionDownloadIsRequestedBeforeReadingUnavailableOrStaleContent() throws {
        let (cloud, _, _) = try roots()
        let absent = cloud.appendingPathComponent("not-materialized.json")
        for status in [URLUbiquitousItemDownloadingStatus.notDownloaded, .downloaded] {
            var requested: [URL] = []
            XCTAssertThrowsError(try CloudSettingsSync.readRevision(absent, downloadStatus: { _ in status },
                                                                   requestDownload: { requested.append($0) })) { error in
                XCTAssertEqual(String(describing: error), "awaitingDownload")
            }
            XCTAssertEqual(requested, [absent])
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: absent.path))
    }

    func testDownloadedAndLocalRevisionBytesAreReadWithoutRequestingAnotherDownload() throws {
        let (cloud, _, _) = try roots()
        let file = cloud.appendingPathComponent("ready.json")
        let expected = Data("{\"revision\":\"ready\"}".utf8)
        try expected.write(to: file)
        for status: URLUbiquitousItemDownloadingStatus? in [.current, nil] {
            var downloads = 0
            let data = try CloudSettingsSync.readRevision(file, downloadStatus: { _ in status },
                                                         requestDownload: { _ in downloads += 1 })
            XCTAssertEqual(data, expected)
            XCTAssertEqual(downloads, 0)
        }
    }

    func testDownloadAccessErrorsAreNotMistakenForACompletedOrPendingTransfer() throws {
        let (cloud, _, _) = try roots()
        XCTAssertThrowsError(try CloudSettingsSync.readRevision(cloud.appendingPathComponent("private.json"),
                                                               downloadStatus: { _ in .notDownloaded },
                                                               requestDownload: { _ in throw CocoaError(.fileReadNoPermission) })) { error in
            XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain)
            XCTAssertEqual((error as NSError).code, CocoaError.fileReadNoPermission.rawValue)
        }
    }

}
