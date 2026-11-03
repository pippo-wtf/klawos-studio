import Foundation

/// Local helper preferences; deliberately excluded from SharedSettings/iCloud.
public struct HelperPreferences {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var startAtLogin: Bool {
        get { defaults.object(forKey: "startAtLogin") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "startAtLogin") }
    }
    public func recordStop(explicit: Bool) {
        if explicit { wasRunning=false }
    }
    // Older releases always tried to start configured actions when Studio opened.
    // Preserve that behavior for existing configurations until an explicit stop.
    public var wasRunning: Bool {
        get { defaults.object(forKey: "macActionsWereRunning") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "macActionsWereRunning") }
    }
}

public enum HelperStartupPolicy {
    public static func shouldRefreshRegistration(currentBuild: String?, registeredBuild: String?) -> Bool {
        guard let currentBuild else { return false }
        return currentBuild != registeredBuild
    }
    public static func shouldResetResumeBackoff(previousBoardPresent: Bool, boardPresent: Bool,
                                              previousPermissionsGranted: Bool, permissionsGranted: Bool) -> Bool {
        (!previousBoardPresent && boardPresent) || (!previousPermissionsGranted && permissionsGranted)
    }

    /// Back off failed verified starts without preventing a later automatic recovery.
    /// Times use system uptime so clock adjustments cannot trigger a retry burst.
    public static func shouldAttemptResume(pending: Bool, wantsOn: Bool, lostKeyboard: Bool,
                                          boardPresent: Bool, permissionsGranted: Bool,
                                          active: Bool, busy: Bool, vialRunning: Bool = false, failures: Int,
                                          lastAttempt: TimeInterval?, now: TimeInterval) -> Bool {
        guard pending || (wantsOn && lostKeyboard), boardPresent, permissionsGranted,
              !active, !busy, !vialRunning else { return false }
        guard failures > 0, let lastAttempt else { return true }
        let delay = min(300.0, 15.0 * pow(2.0, Double(min(failures - 1, 5))))
        return now - lastAttempt >= delay
    }

    public static func shouldStayRunning(startAtLogin: Bool, studioRequested: Bool) -> Bool {
        startAtLogin || studioRequested
    }
    public static func shouldResume(startAtLogin: Bool, wasRunning: Bool, configured: Bool) -> Bool {
        startAtLogin && wasRunning && configured
    }
}
