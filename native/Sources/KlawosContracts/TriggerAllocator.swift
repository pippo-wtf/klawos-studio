import Foundation

public enum TriggerAllocationError: Error {
    case unreadableConfiguration, unsupportedConfiguration, invalidInput, exhausted, inheritedLayerConflict
}

/// Conservative first allocation: reserves a base F-key if it appears anywhere,
/// even under modifiers or in metadata inside a known emission region.
public struct TriggerAllocator {
    public init() {}
    public func allocate(snapshot: Snapshot, helperInputs: [InputID], verifiedLayerOutputs: [FieldPath: JSONValue] = [:]) throws -> TriggerPlan {
        guard snapshot.unreadableFields.isEmpty else { throw TriggerAllocationError.unreadableConfiguration }
        let known: Set<String> = ["version", "uid", "layout_options", "layout", "encoder_layout", "macro", "tap_dance", "combo", "key_override", "alt_repeat_key", "settings", "via_protocol", "vial_protocol"]
        guard Set(snapshot.hardware.keys).isSubset(of: known), snapshot.identity.vialProtocol == 5,
              !snapshot.revision.isEmpty else { throw TriggerAllocationError.unsupportedConfiguration }
        guard Set(helperInputs).count == helperInputs.count,
              case .array(let layers) = snapshot.hardware["layout"],
              let first = layers.first, case .array(let rows) = first else { throw TriggerAllocationError.invalidInput }
        var preservationEdits: [FieldEdit] = []
        var usedOutputs = Set<FieldPath>()
        var scanLayers = layers
        var scanRows = rows
        let controls = try helperInputs.sorted().map { id -> (InputID, String, String?) in
            let parts = id.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0] == "key", let row = Int(parts[1]), let column = Int(parts[2]),
                  row >= 0, row < rows.count, column >= 0,
                  case .array(let keys) = rows[row], column < keys.count,
                  id == "key:\(row):\(column)", !(row == 0 && column == 3) else { throw TriggerAllocationError.invalidInput }
            for (layerIndex, layer) in layers.enumerated().dropFirst() {
                guard case .array(let otherRows) = layer, row < otherRows.count,
                      case .array(let otherKeys) = otherRows[row], column < otherKeys.count else {
                    throw TriggerAllocationError.unsupportedConfiguration
                }
                if isTransparent(otherKeys[column]) {
                    let path = "hardware.layout.\(layerIndex).\(row).\(column)"
                    guard let output = verifiedLayerOutputs[path], !isTransparent(output) else {
                        throw TriggerAllocationError.inheritedLayerConflict
                    }
                    switch output {
                    case .string, .integer: break
                    default: throw TriggerAllocationError.unsupportedConfiguration
                    }
                    usedOutputs.insert(path)
                    preservationEdits.append(FieldEdit(path: path, value: output))
                    guard case .array(var updatedRows) = scanLayers[layerIndex],
                          case .array(var updatedKeys) = updatedRows[row] else {
                        throw TriggerAllocationError.unsupportedConfiguration
                    }
                    updatedKeys[column] = output; updatedRows[row] = .array(updatedKeys)
                    scanLayers[layerIndex] = .array(updatedRows)
                }
            }
            var cleanKeys: [JSONValue]
            if case .array(let current) = scanRows[row] { cleanKeys = current } else { throw TriggerAllocationError.invalidInput }
            cleanKeys[column] = .string("KC_NO"); scanRows[row] = .array(cleanKeys)
            let old: String? = if case .string(let code) = keys[column] { code } else { nil }
            return (id, "hardware.layout.0.\(row).\(column)", old)
        }
        guard usedOutputs == Set(verifiedLayerOutputs.keys) else { throw TriggerAllocationError.invalidInput }
        scanLayers[0] = .array(scanRows)
        var scanHardware = snapshot.hardware
        scanHardware["layout"] = .array(scanLayers)
        var occupied = Set<Int>()
        for field in ["layout", "encoder_layout", "macro", "tap_dance", "combo", "key_override", "alt_repeat_key"] {
            if let value = scanHardware[field] { try scan(value, occupied: &occupied, depth: 0) }
        }
        // Qualified chords require separate physical acceptance and are not silently enabled.
        var available = (13...20).filter { !occupied.contains($0) }
        guard available.count >= controls.count else { throw TriggerAllocationError.exhausted }
        var allocations: [InputID: String] = [:]; var edits: [FieldEdit] = []
        // Reserve existing mappings first, so a newly added earlier control cannot steal one.
        for (id, _, old) in controls {
            if let old, let index = available.firstIndex(where: { "KC_F\($0)" == old }) {
                allocations[id] = old; available.remove(at: index)
            }
        }
        for (id, path, _) in controls {
            let chord: String
            if let existing = allocations[id] { chord = existing }
            else { chord = "KC_F\(available.removeFirst())"; allocations[id] = chord }
            edits.append(FieldEdit(path: path, value: .string(chord)))
        }
        return TriggerPlan(allocations: allocations, fieldEdits: edits + preservationEdits.sorted { $0.path < $1.path }, sourceRevision: snapshot.revision)
    }

    private func isTransparent(_ value: JSONValue) -> Bool {
        switch value {
        case .integer(1): return true
        case .string(let code): return ["KC_TRNS", "KC_TRANSPARENT", "TRNS", "_______", "1", "0x1", "0x0001"].contains(code)
        default: return false
        }
    }

    private func scan(_ value: JSONValue, occupied: inout Set<Int>, depth: Int) throws {
        guard depth <= 32 else { throw TriggerAllocationError.unsupportedConfiguration }
        func reserve(_ n: Int64) {
            // Also reserve the base byte of mod-tap/layer-tap/modified keycodes.
            let base = n & 0xff
            if (104...115).contains(base) { occupied.insert(Int(base) - 91) }
        }
        switch value {
        case .array(let values):
            for child in values { try scan(child, occupied: &occupied, depth: depth + 1) }
        case .object(let values):
            for child in values.values { try scan(child, occupied: &occupied, depth: depth + 1) }
        case .integer(let n): reserve(n)
        case .string(let text):
            // Arbitrary arithmetic needs the protocol parser, not a guessed string match.
            if text.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/~|&^<>")) != nil {
                throw TriggerAllocationError.unsupportedConfiguration
            }
            let pattern = #"(?i)\b(?:KC_)?F(1[3-9]|2[0-4])\b|\b0x[0-9a-f]+\b|\b[0-9]+\b"#
            let expression = try NSRegularExpression(pattern: pattern)
            let ns = text as NSString
            for match in expression.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                if match.range(at: 1).location != NSNotFound, let f = Int(ns.substring(with: match.range(at: 1))) {
                    occupied.insert(f)
                } else {
                    let token = ns.substring(with: match.range).lowercased()
                    if let n = token.hasPrefix("0x") ? Int64(token.dropFirst(2), radix: 16) : Int64(token) { reserve(n) }
                }
            }
        case .number: throw TriggerAllocationError.unsupportedConfiguration
        case .null, .bool: break
        }
    }
}
