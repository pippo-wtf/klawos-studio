import Foundation
import XCTest
@testable import KlawosContracts
final class ProjectStoreTests: XCTestCase {
    private func sample() -> Draft {
        let identity=DeviceIdentity(uid:"6994672159869375106",viaProtocol:9,vialProtocol:5,definitionHash:"test")
        let snapshot=Snapshot(identity:identity,hardware:["layout":.array([.array([.array([.string("KC_A")])])])],lighting:[:],capabilities:[:],unreadableFields:[],metadata:[:],capturedAt:"",revision:"base")
        let config=HelperConfiguration(generation:UUID(),triggerMapRevision:"base",bindings:[:])
        return Draft(baseline:snapshot,proposed:snapshot,dirtyFields:[],sourceRevision:"base",helperConfiguration:config)
    }
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("klawos-test-\(UUID().uuidString)") }
    func testPatchRequiresCurrentRevisionAndFlushesAtApply() throws {
        let dir=root();defer { try? FileManager.default.removeItem(at:dir) }
        let id=UUID(); let store=ProjectStore(root:dir)
        try store.create(projectID:id,draft:sample())
        XCTAssertThrowsError(try store.patch(projectID:id,revision:"old",edits:[FieldEdit(path:"hardware.layout.0.0.0",value:.string("KC_B"))]))
        let revised=try store.patch(projectID:id,revision:"base",edits:[FieldEdit(path:"hardware.layout.0.0.0",value:.string("KC_B"))])
        XCTAssertNotEqual(revised.sourceRevision,"base")
        try store.flush(projectID:id)
        XCTAssertEqual(try ProjectStore(root:dir).load(projectID:id).proposed.hardware["layout"], revised.proposed.hardware["layout"])
    }
    func testFailedAtomicSaveLeavesOldBytes() throws {
        let dir=root();defer { try? FileManager.default.removeItem(at:dir) }
        let id=UUID();let store=ProjectStore(root:dir)
        try store.create(projectID:id,draft:sample())
        store.failBeforeReplace=true
        _ = try store.patch(projectID:id,revision:"base",edits:[FieldEdit(path:"hardware.layout.0.0.0",value:.string("KC_B"))])
        XCTAssertThrowsError(try store.flush(projectID:id))
        XCTAssertEqual(try ProjectStore(root:dir).load(projectID:id).sourceRevision,"base")
    }
    func testHelperProfilePatchChangesRevisionAndSurvivesReload() throws {
        let dir=root();defer { try? FileManager.default.removeItem(at:dir) }
        let id=UUID();let store=ProjectStore(root:dir)
        try store.create(projectID:id,draft:sample())
        let binding: JSONValue = .object(["default":.object(["kind":.string("none")])])
        let revised=try store.patch(projectID:id,revision:"base",edits:[FieldEdit(path:"helperConfiguration.bindings.key:0:0",value:binding)])
        XCTAssertNotEqual(revised.sourceRevision,"base")
        try store.flush(projectID:id)
        XCTAssertEqual(try ProjectStore(root:dir).load(projectID:id).helperConfiguration.bindings["key:0:0"]?["default"], .object(["kind":.string("none")]))
    }
    func testDebouncedAutosaveAndPrivateBackup() throws {
        let dir=root();defer { try? FileManager.default.removeItem(at:dir) }
        let id=UUID();let store=ProjectStore(root:dir)
        try store.create(projectID:id,draft:sample())
        let revised=try store.patch(projectID:id,revision:"base",edits:[FieldEdit(path:"hardware.layout.0.0.0",value:.string("KC_B"))])
        Thread.sleep(forTimeInterval:0.45)
        XCTAssertEqual(try ProjectStore(root:dir).load(projectID:id).sourceRevision,revised.sourceRevision)
        var snapshot=sample().baseline
        snapshot.metadata=["permissions":.string("private"),"credential":.string("private")]
        let ref=try store.backup(projectID:id,snapshot:snapshot,recoveryID:nil)
        let backup=dir.appendingPathComponent("backups/\(id.uuidString)/\(ref.backupID.uuidString).json")
        let raw=try String(contentsOf:backup,encoding:.utf8)
        XCTAssertFalse(raw.contains("private"))
        let attributes=try FileManager.default.attributesOfItem(atPath:backup.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue,0o600)
    }
    func testBackupsRetainTwentyPlusRecoveryReferences() throws {
        let dir=root();defer { try? FileManager.default.removeItem(at:dir) }
        let id=UUID();let store=ProjectStore(root:dir)
        for n in 0..<24 {
            var snapshot=sample().baseline;snapshot.revision="r\(n)"
            _ = try store.backup(projectID:id,snapshot:snapshot,recoveryID:n==0 ? UUID() : nil)
        }
        XCTAssertEqual(try store.backupCount(projectID:id),21)
    }
}
