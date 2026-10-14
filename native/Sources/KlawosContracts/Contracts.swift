import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), integer(Int64), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}
public typealias JSONObject = [String: JSONValue]
public typealias InputID = String
public typealias FieldPath = String
public typealias Capabilities = JSONObject
public typealias LightingState = JSONObject
public typealias AppMetadata = JSONObject
public typealias PortableProfiles = JSONObject
public typealias DiagnosticState = JSONObject
public typealias FeatureModel = JSONObject
public typealias FeatureEdit = JSONObject
public typealias MacroEvent = JSONObject
public typealias ContextBindings = JSONObject

public struct DeviceDescriptor: Codable, Equatable, Sendable {
    public var pathToken: String
    public var vendorID: Int
    public var productID: Int
    public var transport: String
    public var serial: String?
}
public struct DeviceIdentity: Codable, Equatable, Sendable {
    public var uid: String
    public var viaProtocol: Int
    public var vialProtocol: Int
    public var definitionHash: String
    public init(uid: String, viaProtocol: Int, vialProtocol: Int, definitionHash: String) {
        self.uid=uid; self.viaProtocol=viaProtocol; self.vialProtocol=vialProtocol; self.definitionHash=definitionHash
    }
}
public struct Snapshot: Codable, Equatable, Sendable {
    public var identity: DeviceIdentity
    public var hardware: JSONObject
    public var lighting: LightingState
    public var capabilities: Capabilities
    public var unreadableFields: [String]
    public var metadata: AppMetadata
    public var capturedAt: String
    public var revision: String
}
public struct ActionDescriptor: Codable, Equatable, Sendable {
    public var kind: String
    public var id: String?
    public var parameters: JSONObject
}
public struct HelperConfiguration: Codable, Equatable, Sendable {
    public var generation: UUID
    public var triggerMapRevision: String
    public var bindings: [InputID: ContextBindings]
}
public struct Draft: Codable, Equatable, Sendable {
    public var baseline: Snapshot
    public var proposed: Snapshot
    public var dirtyFields: [FieldPath]
    public var sourceRevision: String
    public var helperConfiguration: HelperConfiguration
}
public struct FieldEdit: Codable, Equatable, Sendable { public var path: FieldPath; public var value: JSONValue }
public struct BackupRef: Codable, Equatable, Sendable {
    public var backupID: UUID; public var projectID: UUID; public var deviceIdentity: DeviceIdentity; public var revision: String
}
public struct DeviceOperation: Codable, Equatable, Sendable {
    public var operationID: UUID; public var fieldPaths: [FieldPath]; public var expectedOld: JSONValue
    public var desiredNew: JSONValue; public var regionID: String
}
public struct ChangePlan: Codable, Equatable, Sendable {
    public var operations: [DeviceOperation]; public var sourceRevision: String; public var backup: BackupRef?
    public var stagedHelperGeneration: UUID?; public var requiredDecisions: [String]
}
public struct ApplyResult: Codable, Equatable, Sendable {
    public var state: String; public var verifiedFields: [FieldPath]; public var unresolvedFields: [FieldPath]
    public var finalRevision: String?; public var backup: BackupRef?; public var helperActivated: Bool
}
public struct RecoveryJournal: Codable, Equatable, Sendable {
    public var recoveryID: UUID; public var plan: ChangePlan; public var backup: BackupRef
    public var completedOperations: [UUID]; public var observed: JSONObject
}
public enum RecoveryChoice: String, Codable, Sendable { case keepCurrent, completeIntended, restoreChangedRegions }
public struct MergeResult: Codable, Sendable { public var snapshot: Snapshot; public var conflicts: [FieldPath] }
public typealias ValidatedProject = JSONObject
public struct TriggerPlan: Codable, Sendable {
    public var allocations: [InputID: String]; public var fieldEdits: [FieldEdit]; public var sourceRevision: String
}
public struct InputSample: Sendable {
    public var sourceID: String; public var input: InputID; public var phase: String
    public var synthetic: Bool; public var timestamp: UInt64
    public var keyCode: UInt16 = 0
}
public enum RoutedInput: Equatable, Sendable { case passThrough, consumed, helperPress(InputID), helperRelease(InputID), ignoredSynthetic }
public enum StopReason: String, Codable, Sendable { case stop, disconnect, permissionRevoked, generationChanged, crashRecovery }
public struct ContextSnapshot: Codable, Sendable {
    public var frontmostBundleID: String?; public var lastExternalBundleID: String?
    public var resolvedProfile: String; public var helperState: String; public var permissions: JSONObject
}
public struct ResolvedBinding: Codable, Sendable { public var profileID: String; public var inherited: Bool; public var action: ActionDescriptor }
public struct PressToken: Sendable { public var id: UUID; public var input: InputID; public var context: ContextSnapshot; public var binding: ResolvedBinding }
public struct Availability: Codable, Sendable { public var state: String; public var reason: String }
public struct ActionResult: Codable, Sendable { public var actionID: String; public var state: String; public var reason: String }
public struct RecordingStatus: Codable, Sendable { public var sessionID: UUID; public var active: Bool; public var permission: String; public var eventCount: Int }
public struct ImportPreview: Codable, Sendable { public var proposed: JSONObject; public var missingLocalBindings: [String]; public var changeSummary: [FieldPath] }
public typealias WorkerOperation = JSONObject
public typealias WorkerResult = JSONObject
public typealias WorkerMessage = JSONObject
public enum FeatureID: String, Codable, Sendable { case keymap, encoders, layers, macros, lighting, tapDance, combos, keyOverrides, qmkSettings, matrixTester, importExport, keyboardLayout, security, deviceInfo, altRepeatKey, firmware }
public typealias BridgeMessage = AgentRequest
public typealias BridgeResponse = AgentResponse

public struct AgentRequest: Codable, Sendable {
    public var requestID: String
    public var deviceGeneration: String
    public var operation: String
    public var draftRevision: String?
    public var payload: JSONObject
}
public struct AgentResponse: Codable, Sendable {
    public var requestID: String; public var deviceGeneration: String
    public var payload: JSONObject?; public var errorCode: String?; public var reason: String?
}
public enum ContractError: Error { case malformed, tooLarge, duplicateKey, tooDeep, unknownOperation, staleRevision }

public enum WireCodec {
    public static func decodeRequest(_ data: Data, knownRevisions: Set<String>) throws -> AgentRequest {
        guard data.count <= 4 * 1024 * 1024 else { throw ContractError.tooLarge }
        var scanner = JSONStructureScanner(data: data)
        try scanner.validate()
        let request = try JSONDecoder().decode(AgentRequest.self, from: data)
        guard !request.requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.deviceGeneration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.requestID.count <= 128, request.deviceGeneration.count <= 128 else { throw ContractError.malformed }
        let allowed: Set<String> = ["status", "read", "selectDevice", "patch", "discard", "preview", "apply", "recover",
                                   "import", "export", "feature", "matrixStart", "matrixStop", "recordingStart", "recordingStop",
                                   "security", "helperSettings", "recheck", "diagnostics"]
        guard allowed.contains(request.operation) else { throw ContractError.unknownOperation }
        if ["patch", "discard", "apply"].contains(request.operation) {
            guard let revision = request.draftRevision, knownRevisions.contains(revision) else { throw ContractError.staleRevision }
        }
        return request
    }
}

// Foundation's JSON decoder accepts duplicate keys; scan containers before decoding.
private struct JSONStructureScanner {
    private let bytes: [UInt8]
    private var index = 0
    init(data: Data) { bytes = Array(data) }
    mutating func validate() throws {
        try value(depth: 0); whitespace()
        guard index == bytes.count else { throw ContractError.malformed }
    }
    private mutating func whitespace() { while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 } }
    private mutating func consume(_ byte: UInt8) throws {
        whitespace(); guard index < bytes.count && bytes[index] == byte else { throw ContractError.malformed }; index += 1
    }
    private mutating func string() throws -> String {
        whitespace(); let start = index; try consume(34)
        while index < bytes.count {
            if bytes[index] == 92 { index += 2; continue }
            if bytes[index] == 34 {
                index += 1
                return try JSONDecoder().decode(String.self, from: Data(bytes[start..<index]))
            }
            index += 1
        }
        throw ContractError.malformed
    }
    private mutating func value(depth: Int) throws {
        whitespace(); guard index < bytes.count else { throw ContractError.malformed }
        switch bytes[index] {
        case 123:
            guard depth < 32 else { throw ContractError.tooDeep }; index += 1; whitespace()
            if index < bytes.count && bytes[index] == 125 { index += 1; return }
            var keys = Set<String>()
            while true {
                let key = try string(); guard keys.insert(key).inserted else { throw ContractError.duplicateKey }
                try consume(58); try value(depth: depth + 1); whitespace()
                guard index < bytes.count else { throw ContractError.malformed }
                if bytes[index] == 125 { index += 1; return }; try consume(44)
            }
        case 91:
            guard depth < 32 else { throw ContractError.tooDeep }; index += 1; whitespace()
            if index < bytes.count && bytes[index] == 93 { index += 1; return }
            while true {
                try value(depth: depth + 1); whitespace(); guard index < bytes.count else { throw ContractError.malformed }
                if bytes[index] == 93 { index += 1; return }; try consume(44)
            }
        case 34: _ = try string()
        default:
            let start = index
            while index < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) { index += 1 }
            guard index > start else { throw ContractError.malformed }
        }
    }
}
