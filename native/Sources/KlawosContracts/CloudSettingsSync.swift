import Foundation

public struct SharedSettings: Codable, Equatable, Sendable {
    public var profiles: [InputID: ContextBindings]
    public var layerNames: [String]
    public init(profiles: [InputID: ContextBindings], layerNames: [String]) {
        self.profiles = profiles
        self.layerNames = layerNames
    }
    public var isEmpty: Bool { profiles.isEmpty && layerNames.isEmpty }
}

public struct SyncRevision: Codable, Sendable {
    public var formatVersion: Int
    public var id: UUID
    public var parents: [UUID]
    public var writer: UUID
    public var uid: String
    public var definitionHash: String
    public var settings: SharedSettings
}

public enum SyncDecision {
    case unavailable, waiting, current, incoming(SyncRevision), conflict, invalid
}

private enum CloudRevisionReadError: Error { case awaitingDownload }

public final class CloudSettingsSync {
    private struct LocalState: Codable {
        var writer: UUID
        var applied: UUID?
        var settings: SharedSettings?
        var pending: SharedSettings?
    }
    private let cloudRoot: URL
    private let stateFile: URL
    private var state: LocalState
    private let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.outputFormatting = [.sortedKeys]
        return value
    }()

    public init(cloudRoot: URL, localRoot: URL) throws {
        self.cloudRoot = cloudRoot
        self.stateFile = localRoot.appendingPathComponent("sync-state.json")
        if let data = try? Data(contentsOf: stateFile),
           let saved = try? JSONDecoder().decode(LocalState.self, from: data) {
            state = saved
        } else {
            state = LocalState(writer: UUID(), applied: nil, settings: nil)
            try DurableFile.write(JSONEncoder().encode(state), to: stateFile)
        }
    }

    public var localSettings: SharedSettings? { state.settings }
    public var pendingSettings: SharedSettings? { state.pending }
    public var appliedRevision: UUID? { state.applied }

    private func directory(uid: String, definitionHash: String) -> URL? {
        guard !uid.isEmpty, uid.allSatisfy({ $0.isNumber }),
              definitionHash.count == 64,
              definitionHash.allSatisfy({ $0.isHexDigit }),
              FileManager.default.fileExists(atPath: cloudRoot.path) else { return nil }
        return cloudRoot.appendingPathComponent("KLAWOS Studio/Settings", isDirectory: true)
            .appendingPathComponent(uid + "-" + definitionHash.lowercased(), isDirectory: true)
    }

    private func validate(_ settings: SharedSettings) -> Bool {
        guard settings.profiles.count <= 16, settings.layerNames.count <= 16,
              settings.layerNames.allSatisfy({ $0.count <= 80 && !$0.contains("\0") }) else { return false }
        for (input, value) in settings.profiles {
            guard input.range(of: #"^key:[0-9]{1,2}:[0-9]{1,2}$"#, options: .regularExpression) != nil,
                  Set(value.keys).isSubset(of: ["default", "overrides"]),
                  (try? ContextRouter.resolve(bundleID: nil, bindings: value)) != nil else { return false }
            if case .object(let overrides) = value["overrides"] {
                guard overrides.count <= 16 else { return false }
                for bundle in overrides.keys {
                    guard bundle.count <= 255,
                          bundle.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil,
                          (try? ContextRouter.resolve(bundleID: bundle, bindings: value)) != nil else { return false }
                }
            } else if value["overrides"] != nil { return false }
        }
        return true
    }

    static func readRevision(_ file: URL,
                             downloadStatus: (URL) throws -> URLUbiquitousItemDownloadingStatus? = {
                                 try $0.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
                             },
                             requestDownload: (URL) throws -> Void = {
                                 try FileManager.default.startDownloadingUbiquitousItem(at: $0)
                             }) throws -> Data {
        if let status = try downloadStatus(file), status != .current {
            try requestDownload(file)
            throw CloudRevisionReadError.awaitingDownload
        }
        return try Data(contentsOf: file)
    }

    private func revisions(uid: String, definitionHash: String) throws -> [SyncRevision]? {
        guard let folder = directory(uid: uid, definitionHash: definitionHash) else { return nil }
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        guard files.count <= 1000 else { throw ContractError.tooLarge }
        return try files.map { file in
            let data = try Self.readRevision(file)
            guard data.count <= 256 * 1024 else { throw ContractError.tooLarge }
            let revision = try JSONDecoder().decode(SyncRevision.self, from: data)
            guard revision.formatVersion == 1, revision.uid == uid,
                  revision.definitionHash.lowercased() == definitionHash.lowercased(),
                  revision.id.uuidString == file.deletingPathExtension().lastPathComponent,
                  validate(revision.settings) else { throw ContractError.malformed }
            return revision
        }
    }

    private func heads(uid: String, definitionHash: String) throws -> (SyncDecision, [SyncRevision]) {
        let all: [SyncRevision]
        do {
            guard let loaded = try revisions(uid: uid, definitionHash: definitionHash) else { return (.unavailable, []) }
            all = loaded
        } catch CloudRevisionReadError.awaitingDownload { return (.waiting, []) }
        let ids = Set(all.map(\.id))
        guard all.count == ids.count,
              all.allSatisfy({ Set($0.parents).count == $0.parents.count &&
                                !$0.parents.contains($0.id) }) else { return (.invalid, []) }
        // iCloud can deliver a child revision before its parent. Never publish from a partial history.
        guard all.allSatisfy({ $0.parents.allSatisfy(ids.contains) }) else { return (.waiting, []) }
        let parents = Set(all.flatMap(\.parents))
        let current = all.filter { !parents.contains($0.id) }
        if !all.isEmpty && current.isEmpty { return (.invalid, []) }
        return (current.count > 1 ? .conflict : .current, current)
    }

    private func head(uid: String, definitionHash: String) throws -> (SyncDecision, SyncRevision?) {
        let (decision, current) = try heads(uid: uid, definitionHash: definitionHash)
        return (decision, current.count == 1 ? current[0] : nil)
    }

    private func persist() throws { try DurableFile.write(encoder.encode(state), to: stateFile) }

    public func inspect(uid: String, definitionHash: String, local: SharedSettings) -> SyncDecision {
        guard validate(local) else { return .invalid }
        do {
            let (decision, newest) = try head(uid: uid, definitionHash: definitionHash)
            guard case .current = decision else { return decision }
            guard let newest else { return .current }
            if newest.id == state.applied {
                guard newest.settings == state.settings else { return .invalid }
                return .current
            }
            if newest.settings == local { return .current }
            if let previous = state.settings {
                guard previous == local else { return .conflict }
            } else if !local.isEmpty && !(local.profiles == newest.settings.profiles && local.layerNames.isEmpty) { return .conflict }
            return .incoming(newest)
        } catch { return .invalid }
    }

    public func markApplied(_ revision: SyncRevision) throws {
        if state.pending == revision.settings || state.pending == state.settings { state.pending = nil }
        state.applied = revision.id
        state.settings = revision.settings
        try persist()
    }

    @discardableResult public func publish(uid: String, definitionHash: String, settings: SharedSettings) throws -> SyncDecision {
        guard validate(settings) else { return .invalid }
        // Retain explicit saves through offline storage, partial downloads, and restarts.
        state.pending = settings
        try persist()
        let (decision, newest) = try head(uid: uid, definitionHash: definitionHash)
        guard case .current = decision else { return decision }
        if let newest, newest.settings == settings {
            if state.applied != newest.id || state.settings != settings || state.pending != nil { try markApplied(newest) }
            return .current
        }
        if let newest, newest.id != state.applied { return .conflict }
        guard let folder = directory(uid: uid, definitionHash: definitionHash) else { return .unavailable }
        let revision = SyncRevision(formatVersion: 1, id: UUID(), parents: newest.map { [$0.id] } ?? [],
                                    writer: state.writer, uid: uid, definitionHash: definitionHash,
                                    settings: settings)
        try DurableFile.write(encoder.encode(revision), to: folder.appendingPathComponent(revision.id.uuidString + ".json"))
        try markApplied(revision)
        return .current
    }

    public func otherMacConflict(uid: String, definitionHash: String) throws -> SyncRevision? {
        let (decision, current) = try heads(uid: uid, definitionHash: definitionHash)
        switch decision {
        case .current, .conflict: break
        default: return nil
        }
        let others = current.filter { $0.writer != state.writer }
        return others.count == 1 ? others[0] : nil
    }

    @discardableResult public func resolveConflict(uid: String, definitionHash: String,
                                                    settings: SharedSettings) throws -> SyncDecision {
        guard validate(settings) else { return .invalid }
        let (decision, current) = try heads(uid: uid, definitionHash: definitionHash)
        switch decision {
        case .current, .conflict: break
        default: return decision
        }
        guard let folder = directory(uid: uid, definitionHash: definitionHash) else { return .unavailable }
        if current.count == 1, let newest = current.first, newest.settings == settings {
            state.pending = nil
            try markApplied(newest)
            return inspect(uid: uid, definitionHash: definitionHash, local: settings)
        }
        let revision = SyncRevision(formatVersion: 1, id: UUID(), parents: current.map(\.id),
                                    writer: state.writer, uid: uid, definitionHash: definitionHash,
                                    settings: settings)
        try DurableFile.write(encoder.encode(revision), to: folder.appendingPathComponent(revision.id.uuidString + ".json"))
        state.pending = nil
        try markApplied(revision)
        return inspect(uid: uid, definitionHash: definitionHash, local: settings)
    }
}
