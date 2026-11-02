import Foundation

public enum HelperStartError: Error, Equatable {
    case notConfigured, differentKeyboard, keysChanged, vialOpen, disconnected, boardUnreadable, busy, saveFailed
    public var reason: String {
        switch self {
        case .notConfigured: return "Save a Mac action to the keyboard in Studio first."
        case .differentKeyboard: return "A different keyboard is connected. Connect the keyboard with your saved Mac actions."
        case .keysChanged: return "Mac-action keys were changed on the keyboard. Re-save your keys in Studio."
        case .vialOpen: return "Vial is open. Close Vial, then turn on Mac actions."
        case .disconnected: return "Keyboard not connected. Reconnect it, then turn on Mac actions."
        case .boardUnreadable: return "The keyboard could not be read. Reconnect it and try again."
        case .busy: return "The keyboard is busy. Try again in a moment."
        case .saveFailed: return "Mac-action settings could not be saved on this Mac. Try again."
        }
    }
    public static func reason(for error: Error) -> String {
        if let error = error as? HelperStartError { return error.reason }
        if let error = error as? InputTapError {
            switch error {
            case .permissionRequired: return "Allow KLAWOS Helper in Accessibility and Input Monitoring in System Settings."
            case .disconnected: return Self.disconnected.reason
            case .installationFailed: return "macOS could not listen for Mac-action keys. Check KLAWOS Helper permissions and try again."
            case .alreadyActive: return "Mac actions are already on."
            }
        }
        if error is InputRoutingError { return Self.keysChanged.reason }
        if error is ActionValidationError { return "A saved Mac action could not be read. Re-save it in Studio." }
        return Self.boardUnreadable.reason
    }
}

/// The on-disk helper format, shared with the start verifier so it can be tested without an event tap.
public struct SavedHelper: Codable {
    public let configuration: HelperConfiguration
    public let allocations: [InputID: String]
    public let uid: String
    public let definitionHash: String?
    public init(configuration: HelperConfiguration, allocations: [InputID: String], uid: String, definitionHash: String?) {
        self.configuration=configuration; self.allocations=allocations; self.uid=uid; self.definitionHash=definitionHash
    }
    public func verifiedForStart(snapshot: Snapshot, vialRunning: Bool) throws -> SavedHelper {
        guard !allocations.isEmpty else { throw HelperStartError.notConfigured }
        guard uid == snapshot.identity.uid,
              definitionHash == nil || definitionHash == snapshot.identity.definitionHash else { throw HelperStartError.differentKeyboard }
        guard case .object(let descriptor) = snapshot.metadata["descriptor"],
              case .string(let token) = descriptor["pathToken"], !token.isEmpty else { throw HelperStartError.disconnected }
        guard !vialRunning else { throw HelperStartError.vialOpen }
        guard snapshot.unreadableFields.isEmpty, !snapshot.revision.isEmpty else { throw HelperStartError.boardUnreadable }
        let plan: TriggerPlan
        do { plan = try TriggerAllocator().allocate(snapshot: snapshot, helperInputs: Array(allocations.keys)) }
        catch { throw HelperStartError.keysChanged }
        guard plan.allocations == allocations,
              plan.allocations.allSatisfy({ input, code in
                  let parts = input.split(separator: ":")
                  guard parts.count == 3, let row = Int(parts[1]), let column = Int(parts[2]),
                        case .array(let layers) = snapshot.hardware["layout"],
                        case .array(let rows) = layers.first, rows.indices.contains(row),
                        case .array(let keys) = rows[row], keys.indices.contains(column) else { return false }
                  return keys[column] == .string(code)
              }) else { throw HelperStartError.keysChanged }
        var next = configuration; next.triggerMapRevision = snapshot.revision
        return SavedHelper(configuration: next, allocations: allocations, uid: uid, definitionHash: definitionHash)
    }
    public func persistRevisionChange(from previous: SavedHelper, to file: URL) throws {
        guard configuration.triggerMapRevision != previous.configuration.triggerMapRevision else { return }
        do { try DurableFile.write(JSONEncoder().encode(self), to: file) }
        catch { throw HelperStartError.saveFailed }
    }
}
