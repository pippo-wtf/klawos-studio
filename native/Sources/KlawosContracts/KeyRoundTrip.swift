import Foundation
public enum KeyRoundTripResult: String { case restored, unchanged, recoveryRequired }
public enum KeyRoundTripError: Error { case staleCell, invalidTest }

/// A bounded commissioning proof, not the general Apply coordinator.
public enum KeyRoundTrip {
    public static func run(expected: UInt16, temporary: UInt16, read: () throws -> UInt16, write: (UInt16) throws -> Void, journal: (String) throws -> Void, duringTemporary: () -> Void = {}) throws -> KeyRoundTripResult {
        guard expected == 4, temporary == 104 else { throw KeyRoundTripError.invalidTest }
        guard try read() == expected else { throw KeyRoundTripError.staleCell }
        try journal("apply-intent") // If durability fails, there must be zero writes.
        do { try write(temporary) } catch { /* Outcome is ambiguous: read, never resend. */ }
        do {
            let observed = try read()
            if observed == expected { try journal("unchanged-verified"); return .unchanged }
            guard observed == temporary else { return .recoveryRequired }
            try journal("applied-verified")
            duringTemporary()
            guard try read() == temporary else { return .recoveryRequired }
            try journal("restore-intent")
            do { try write(expected) } catch { /* Verify even if acknowledgement was lost. */ }
            guard try read() == expected else { return .recoveryRequired }
            try journal("restored-verified")
            return .restored
        } catch { return .recoveryRequired }
    }
}

public enum NarrowKeyTestReport {
    public static func validate(_ data: Data) throws -> Data {
        guard data == Data([5,0,0,0,0,104]) || data == Data([5,0,0,0,0,4]) else {
            throw ReadOnlyReport.Failure.forbiddenCommand
        }
        return data + Data(repeating: 0, count: 32 - data.count)
    }
}

public enum NarrowLightingRecoveryReport {
    public static func validate(_ data: Data) throws -> Data {
        guard data == Data([7,0x41,3,0,63,216,93,71]) else { throw ReadOnlyReport.Failure.forbiddenCommand }
        return data + Data(repeating: 0, count: 32 - data.count)
    }
}
