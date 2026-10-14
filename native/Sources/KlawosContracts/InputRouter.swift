import Foundation

public enum InputRoutingError: Error { case invalidReservation, unverifiedConfiguration, activeSession }

/// Confined to one serial event stream. This class never installs an event tap.
public final class InputRouter {
    public private(set) var isActive = false
    private var chords: [String: InputID] = [:]
    private var held: [UInt16: InputID] = [:]
    private var pendingReleases: [InputID] = []
    private var generation: UUID?
    private var revision: String?
    public private(set) var deviceGeneration: String?
    public init() {}

    public func activate(allocations: [InputID: String], configuration: HelperConfiguration, deviceGeneration: String, verifiedRevision: String) throws {
        guard !isActive, held.isEmpty, pendingReleases.isEmpty else { throw InputRoutingError.activeSession }
        guard !deviceGeneration.isEmpty, !verifiedRevision.isEmpty,
              configuration.triggerMapRevision == verifiedRevision else { throw InputRoutingError.unverifiedConfiguration }
        // Modifier-qualified candidates remain disabled until the physical modifier gate passes.
        let allowed = Set((13...20).map { "KC_F\($0)" })
        guard !allocations.isEmpty, Set(allocations.values).count == allocations.count,
              allocations.allSatisfy({ configuration.bindings[$0.key] != nil && allowed.contains($0.value) }) else {
            throw InputRoutingError.invalidReservation
        }
        chords = Dictionary(uniqueKeysWithValues: allocations.map { ($0.value, $0.key) })
        generation = configuration.generation; revision = verifiedRevision
        self.deviceGeneration = deviceGeneration; isActive = true
    }

    public func route(_ sample: InputSample, configuration: HelperConfiguration) -> RoutedInput {
        if sample.synthetic { return .ignoredSynthetic }
        guard isActive else { return .passThrough }
        guard generation == configuration.generation, revision == configuration.triggerMapRevision else {
            pendingReleases += releaseAll(reason: .generationChanged)
            return .passThrough
        }
        if sample.phase == "up", let input = held.removeValue(forKey: sample.keyCode) {
            return .helperRelease(input)
        }
        guard sample.phase == "down" else { return .passThrough }
        if held[sample.keyCode] != nil { return .consumed }
        guard let input = chords[sample.input] else { return .passThrough }
        held[sample.keyCode] = input
        return .helperPress(input)
    }

    @discardableResult public func releaseAll(reason: StopReason) -> [InputID] {
        let releases = held.values.sorted()
        held.removeAll(); chords.removeAll(); generation = nil; revision = nil
        deviceGeneration = nil; isActive = false
        return releases
    }
    public func takePendingReleases() -> [InputID] {
        defer { pendingReleases.removeAll() }
        return pendingReleases
    }
}
