import Foundation
import CoreGraphics
import ApplicationServices

public enum InputTapError: Error { case disconnected, permissionRequired, installationFailed, alreadyActive }

/// Main-thread commissioning harness: counts F13 lifecycle events, never executes
/// actions or reads text. The connection predicate must be a nonblocking cached
/// generation check. The production agent must also deliver disconnect notifications.
public final class InputTapController {
    public private(set) var pressCount = 0
    public private(set) var releaseCount = 0
    public private(set) var cleanupCount = 0
    public var isActive: Bool { router.isActive }
    public private(set) var stopReason: String?
    private let router = InputRouter()
    private let configuration = HelperConfiguration(generation: UUID(), triggerMapRevision: "commissioning-F13", bindings: ["key:0:0": [:]])
    private let deviceGeneration: String
    private let connected: () -> Bool
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    public init(deviceGeneration: String, connected: @escaping () -> Bool) {
        self.deviceGeneration = deviceGeneration; self.connected = connected
    }
    public static var permissions: [String: Bool] {
        ["inputMonitoring": CGPreflightListenEventAccess(), "accessibility": AXIsProcessTrusted()]
    }
    private func prepare() throws {
        precondition(Thread.isMainThread)
        guard !isActive else { throw InputTapError.alreadyActive }
        guard connected() else { throw InputTapError.disconnected }
        try router.activate(allocations: ["key:0:0": "KC_F13"], configuration: configuration,
                            deviceGeneration: deviceGeneration, verifiedRevision: configuration.triggerMapRevision)
        stopReason = nil
    }
    // Internal test seam; it cannot install a tap or request OS permissions.
    func prepareForTest() throws { try prepare() }

    public func start() throws {
        precondition(Thread.isMainThread)
        guard Self.permissions.values.allSatisfy({ $0 }) else { throw InputTapError.permissionRequired }
        try prepare()
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<InputTapController>.fromOpaque(userInfo).takeUnretainedValue()
                guard let result = owner.process(type: type, event: event) else { return nil }
                return Unmanaged.passUnretained(result)
            }, userInfo: context), let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            stop(reason: "installation-failed"); throw InputTapError.installationFailed
        }
        tap = newTap; source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
    }

    public func process(type: CGEventType, event: CGEvent) -> CGEvent? {
        precondition(Thread.isMainThread)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stop(reason: "tap-disabled"); return event
        }
        checkConnection()
        guard isActive, let sample = MacInputEvent.decode(event, type: type) else { return event }
        switch router.route(sample, configuration: configuration) {
        case .helperPress: pressCount += 1; return nil
        case .helperRelease: releaseCount += 1; return nil
        case .consumed: return nil
        case .passThrough, .ignoredSynthetic: return event
        }
    }
    public func checkConnection() {
        precondition(Thread.isMainThread)
        if isActive && !connected() { stop(reason: "disconnected") }
    }
    public func stop(reason: String = "stopped") {
        precondition(Thread.isMainThread)
        cleanupCount += router.releaseAll(reason: .stop).count
        stopReason = reason
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil
    }
    deinit {
        // Owners stop on the main run loop before release; invalidation is a final safeguard.
        if let tap { CFMachPortInvalidate(tap) }
        if let source { CFRunLoopSourceInvalidate(source) }
    }
}
