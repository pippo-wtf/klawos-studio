import Foundation

public struct HelperPresentation: Equatable {
    public let state: String
    public let reason: String
    public var menuTitle: String { state == "running" ? "Mac actions on" : state == "paused" ? "Mac actions paused" : "Mac actions off" }
    public init(active: Bool, reason: String, frontmostBundleID: String?) {
        let paused = active && !MacActionFocusPolicy.shouldHandleKeys(frontmostBundleID: frontmostBundleID)
        state = active ? (paused ? "paused" : "running") : "stopped"
        self.reason = paused ? "Mac actions paused while KLAWOS Studio is active." : reason
    }
}
