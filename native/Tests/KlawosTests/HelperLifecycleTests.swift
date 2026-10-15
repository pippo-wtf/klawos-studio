import XCTest
@testable import KlawosContracts

@MainActor private final class Suspension<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Never>?
    func wait() async -> Value { await withCheckedContinuation { continuation = $0 } }
    func waitUntilSuspended() async { while continuation == nil { await Task.yield() } }
    func resume(_ value: Value) { continuation?.resume(returning: value); continuation = nil }
}

final class HelperLifecycleTests: XCTestCase {
    private func snapshot() -> Snapshot {
        Snapshot(identity: DeviceIdentity(uid: "1", viaProtocol: 9, vialProtocol: 5, definitionHash: "test"), hardware: [:], lighting: [:], capabilities: [:], unreadableFields: [], metadata: [:], capturedAt: "", revision: "baseline")
    }

    @MainActor func testStopCancelsStartWaitingForDeviceRead() async throws {
        let capture = LiveInputCapture()
        let read = Suspension<Snapshot>()
        var activations = 0
        let task = Task { try await capture.startAfterReading({ await read.wait() }, activate: { _ in activations += 1 }) }
        await read.waitUntilSuspended()
        capture.stop()
        read.resume(snapshot())
        let started = try await task.value
        XCTAssertFalse(started)
        XCTAssertEqual(activations, 0, "A delayed read must not turn the helper back on after Stop")
    }

    @MainActor func testIncomingConfigurationDuringStartStillActivates() async throws {
        let capture = LiveInputCapture()
        let read = Suspension<Snapshot>()
        var activations = 0
        let task = Task { try await capture.startAfterReading({ await read.wait() }, activate: { _ in activations += 1 }) }
        await read.waitUntilSuspended()
        let oldActions = capture.executionGeneration
        capture.stopForConfigurationChange()
        XCTAssertNotEqual(capture.executionGeneration, oldActions)
        read.resume(snapshot())
        let started = try await task.value
        XCTAssertTrue(started, "Incoming sync installs must preserve the user's pending Start")
        XCTAssertEqual(activations, 1)
    }

    @MainActor func testExplicitStopBeforeOrAfterIncomingConfigurationStillWins() async throws {
        for stopBeforeInstall in [true, false] {
            let capture = LiveInputCapture()
            let read = Suspension<Snapshot>()
            var activations = 0
            let task = Task { try await capture.startAfterReading({ await read.wait() }, activate: { _ in activations += 1 }) }
            await read.waitUntilSuspended()
            if stopBeforeInstall { capture.stop() }
            capture.stopForConfigurationChange()
            if !stopBeforeInstall { capture.stop(reason: "Keyboard disconnected") }
            read.resume(snapshot())
            let started = try await task.value
            XCTAssertFalse(started)
            XCTAssertEqual(activations, 0)
        }
    }

    @MainActor func testLatestStartIntentWinsOverEarlierRead() async throws {
        let capture = LiveInputCapture()
        let read = Suspension<Snapshot>()
        var revisions: [String] = []
        let first = Task { try await capture.startAfterReading({ await read.wait() }, activate: { revisions.append($0.revision) }) }
        await read.waitUntilSuspended()
        var latest = snapshot(); latest.revision = "latest"
        let started = try await capture.startAfterReading({ latest }, activate: { revisions.append($0.revision) })
        XCTAssertTrue(started)
        read.resume(snapshot())
        let superseded = try await first.value
        XCTAssertFalse(superseded)
        XCTAssertEqual(revisions, ["latest"])
    }

    @MainActor func testDelayedAppShortcutIsInvalidatedByStopDisconnectAndConfigurationChange() async throws {
        for reason in ["Stopped", "Keyboard disconnected", "Your settings changed"] {
            let capture = LiveInputCapture()
            let activation = Suspension<Void>()
            var posted: [Int64] = []
            let app = "com.openai.codex"
            let executor = ActionExecutor(apps: .init(applicationURL: { _ in URL(fileURLWithPath: "/fake/app") },
                accessibilityGranted: { true }, frontmostBundleID: { app },
                openApplication: { _ in await activation.wait() }, postShortcut: { key, _ in posted.append(key) }))
            let generation = capture.executionGeneration
            let action = ActionDescriptor(kind: "appShortcut", parameters: ["bundleID": .string(app), "keyCode": .integer(11), "modifiers": .array([.string("command")])])
            let task = Task { await executor.execute(action, isValid: { capture.executionGeneration == generation }) }
            await activation.waitUntilSuspended()
            capture.stop(reason: reason)
            activation.resume(())
            let result = await task.value
            XCTAssertEqual(posted, [], reason)
            XCTAssertEqual(result.state, "cancelled", reason)
        }
    }

    @MainActor func testCurrentAppShortcutStillPostsExactlyOnce() async {
        var posted: [Int64] = []
        let app = "com.openai.codex"
        let executor = ActionExecutor(apps: .init(applicationURL: { _ in URL(fileURLWithPath: "/fake/app") },
            accessibilityGranted: { true }, frontmostBundleID: { app },
            openApplication: { _ in }, postShortcut: { key, _ in posted.append(key) }))
        let action = ActionDescriptor(kind: "appShortcut", parameters: ["bundleID": .string(app), "keyCode": .integer(11), "modifiers": .array([.string("command")])])
        let result = await executor.execute(action)
        XCTAssertEqual(result.state, "executed")
        XCTAssertEqual(posted, [11])
    }

    func testStatusAndMenuReflectFocusAndExternalStopStart() {
        let on = HelperPresentation(active: true, reason: "Running", frontmostBundleID: "com.apple.TextEdit")
        XCTAssertEqual(on.state, "running"); XCTAssertEqual(on.menuTitle, "Mac actions on")
        let paused = HelperPresentation(active: true, reason: "Running", frontmostBundleID: "com.pippo.klawos.studio")
        XCTAssertEqual(paused.state, "paused"); XCTAssertEqual(paused.menuTitle, "Mac actions paused")
        XCTAssertTrue(paused.reason.contains("Studio"))
        let stopped = HelperPresentation(active: false, reason: "Keyboard disconnected", frontmostBundleID: "com.pippo.klawos.studio")
        XCTAssertEqual(stopped.state, "stopped"); XCTAssertEqual(stopped.menuTitle, "Mac actions off")
        XCTAssertEqual(stopped.reason, "Keyboard disconnected")
        XCTAssertEqual(HelperPresentation(active: true, reason: "Running", frontmostBundleID: nil), on)
    }
}
