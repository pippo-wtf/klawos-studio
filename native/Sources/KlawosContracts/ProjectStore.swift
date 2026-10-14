import Foundation
import CryptoKit
import Darwin

public final class ProjectStore {
    public enum Failure: Error { case missingDraft, staleRevision, invalidField, simulatedWriteFailure }
    private struct BackupRecord: Codable {
        var projectID: UUID
        var recoveryID: UUID?
        var createdAt: Date
        var snapshot: Snapshot
    }
    private let root: URL
    private let lock = NSLock()
    private var drafts: [UUID: Draft] = [:]
    private var scheduled: [UUID: DispatchWorkItem] = [:]
    var failBeforeReplace = false // Fault injection for the atomic-save test.
    public init(root: URL) { self.root = root }
    private func draftURL(_ id: UUID) -> URL { root.appendingPathComponent("drafts").appendingPathComponent(id.uuidString + ".json") }
    private func backupDir(_ id: UUID) -> URL { root.appendingPathComponent("backups").appendingPathComponent(id.uuidString) }
    private func prepare(_ dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    }
    private func writeAtomic<T: Encodable>(_ value: T, to target: URL) throws {
        try prepare(target.deletingLastPathComponent())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(value)
        guard bytes.count <= 4 * 1024 * 1024 else { throw ContractError.tooLarge }
        let temporary = target.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        let created = FileManager.default.createFile(atPath: temporary.path, contents: nil,
                                                     attributes: [.posixPermissions: 0o600])
        guard created else { throw Failure.simulatedWriteFailure }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        do { try handle.write(contentsOf: bytes); try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
        if failBeforeReplace { throw Failure.simulatedWriteFailure }
        guard Darwin.rename(temporary.path, target.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let fd=Darwin.open(target.deletingLastPathComponent().path,O_RDONLY)
        guard fd>=0 else {throw POSIXError(.EIO)}
        defer {Darwin.close(fd)}
        guard fsync(fd)==0 else {throw POSIXError(.EIO)}
    }
    private func loadUnlocked(_ id: UUID) throws -> Draft {
        if let cached = drafts[id] { return cached }
        let url = draftURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { throw Failure.missingDraft }
        let data = try Data(contentsOf: url)
        guard data.count <= 4 * 1024 * 1024 else { throw ContractError.tooLarge }
        let draft = try JSONDecoder().decode(Draft.self, from: data)
        drafts[id] = draft
        return draft
    }
    public func create(projectID: UUID, draft: Draft) throws {
        try lock.withLock {
            try writeAtomic(draft, to: draftURL(projectID))
            drafts[projectID] = draft
        }
    }
    public func load(projectID: UUID) throws -> Draft { try lock.withLock { try loadUnlocked(projectID) } }
    private func edited(_ original: JSONValue, components: ArraySlice<String>, value: JSONValue) throws -> JSONValue {
        guard let head = components.first else { return value }
        if case .object(var entries) = original {
            if let child = entries[head] {
                entries[head] = try edited(child, components: components.dropFirst(), value: value)
            } else if components.count == 1 {
                entries[head] = value
            } else { throw Failure.invalidField }
            return .object(entries)
        }
        if case .array(var entries) = original, let index = Int(head), entries.indices.contains(index) {
            entries[index] = try edited(entries[index], components: components.dropFirst(), value: value)
            return .array(entries)
        }
        throw Failure.invalidField
    }
    private func revision(_ draft: Draft) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let helperData = try encoder.encode(draft.helperConfiguration)
        let helper = try JSONDecoder().decode(JSONValue.self, from: helperData)
        let fields: [String: JSONValue] = ["hardware": .object(draft.proposed.hardware),
                                           "lighting": .object(draft.proposed.lighting),
                                           "helperConfiguration": helper]
        let bytes = try encoder.encode(fields)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    public func patch(projectID: UUID, revision expected: String, edits: [FieldEdit]) throws -> Draft {
        try lock.withLock {
            var draft = try loadUnlocked(projectID)
            guard draft.sourceRevision == expected else { throw Failure.staleRevision }
            for edit in edits {
                let pieces = edit.path.split(separator: ".").map(String.init)
                guard pieces.count >= 2 else { throw Failure.invalidField }
                if pieces[0] == "hardware" {
                    let next = try edited(.object(draft.proposed.hardware), components: pieces.dropFirst(), value: edit.value)
                    guard case .object(let hardware) = next else { throw Failure.invalidField }
                    draft.proposed.hardware = hardware
                } else if pieces[0] == "lighting" {
                    let next = try edited(.object(draft.proposed.lighting), components: pieces.dropFirst(), value: edit.value)
                    guard case .object(let lighting) = next else { throw Failure.invalidField }
                    draft.proposed.lighting = lighting
                } else if pieces[0] == "helperConfiguration" {
                    let current = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(draft.helperConfiguration))
                    let next = try edited(current, components: pieces.dropFirst(), value: edit.value)
                    draft.helperConfiguration = try JSONDecoder().decode(HelperConfiguration.self, from: JSONEncoder().encode(next))
                } else { throw Failure.invalidField }
                if !draft.dirtyFields.contains(edit.path) { draft.dirtyFields.append(edit.path) }
            }
            draft.sourceRevision = try revision(draft)
            draft.proposed.revision = draft.sourceRevision
            drafts[projectID] = draft
            scheduled[projectID]?.cancel()
            let item = DispatchWorkItem { [weak self] in try? self?.flush(projectID: projectID) }
            scheduled[projectID] = item
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(300), execute: item)
            return draft
        }
    }
    public func flush(projectID: UUID) throws {
        try lock.withLock {
            let draft = try loadUnlocked(projectID)
            try writeAtomic(draft, to: draftURL(projectID))
            scheduled[projectID]?.cancel(); scheduled[projectID] = nil
        }
    }
    public func backup(projectID: UUID, snapshot: Snapshot, recoveryID: UUID?) throws -> BackupRef {
        try lock.withLock {
            let backupID = UUID()
            var clean = snapshot
            clean.metadata = [:] // Local permissions and paths are never a portable backup field.
            let record = BackupRecord(projectID: projectID, recoveryID: recoveryID, createdAt: Date(), snapshot: clean)
            try writeAtomic(record, to: backupDir(projectID).appendingPathComponent(backupID.uuidString + ".json"))
            try prune(projectID: projectID)
            return BackupRef(backupID: backupID, projectID: projectID, deviceIdentity: snapshot.identity,
                             revision: snapshot.revision)
        }
    }
    private func backupRecords(projectID: UUID) throws -> [(URL, BackupRecord)] {
        let dir = backupDir(projectID)
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { ($0, try JSONDecoder().decode(BackupRecord.self, from: Data(contentsOf: $0))) }
    }
    private func prune(projectID: UUID) throws {
        let records = try backupRecords(projectID: projectID).sorted { $0.1.createdAt > $1.1.createdAt }
        var unprotected = 0
        for (url, record) in records {
            if record.recoveryID != nil { continue }
            unprotected += 1
            if unprotected > 20 { try FileManager.default.removeItem(at: url) }
        }
    }
    public func backupCount(projectID: UUID) throws -> Int { try lock.withLock { try backupRecords(projectID: projectID).count } }
}
