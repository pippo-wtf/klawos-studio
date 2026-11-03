import XCTest
@testable import KlawosContracts

final class HelperStartupTests: XCTestCase {
    func testAbsentPreferencesEnableLoginAndLegacyResume() {
        let name="KlawosStartupTests."+UUID().uuidString
        let defaults=UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let preferences=HelperPreferences(defaults:defaults)
        XCTAssertTrue(preferences.startAtLogin)
        XCTAssertTrue(preferences.wasRunning)
    }
    func testTogglePersistsBothDirectionsAndStopIntent() {
        let name="KlawosStartupTests."+UUID().uuidString
        let defaults=UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let preferences=HelperPreferences(defaults:defaults)
        preferences.startAtLogin=false
        preferences.wasRunning=false
        XCTAssertFalse(HelperPreferences(defaults:defaults).startAtLogin)
        XCTAssertFalse(HelperPreferences(defaults:defaults).wasRunning)
        preferences.startAtLogin=true
        preferences.wasRunning=true
        XCTAssertTrue(HelperPreferences(defaults:defaults).startAtLogin)
        XCTAssertTrue(HelperPreferences(defaults:defaults).wasRunning)
    }
    func testSavePausePreservesIntentButExplicitStopClearsIt() {
        let name="KlawosStartupTests."+UUID().uuidString
        let defaults=UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let preferences=HelperPreferences(defaults:defaults)
        preferences.wasRunning=true
        preferences.recordStop(explicit:false)
        XCTAssertTrue(preferences.wasRunning)
        preferences.recordStop(explicit:true)
        XCTAssertFalse(preferences.wasRunning)
    }
    func testLoginDecisionAndStudioDemand() {
        XCTAssertFalse(HelperStartupPolicy.shouldStayRunning(startAtLogin:false, studioRequested:false))
        XCTAssertTrue(HelperStartupPolicy.shouldStayRunning(startAtLogin:true, studioRequested:false))
        XCTAssertTrue(HelperStartupPolicy.shouldStayRunning(startAtLogin:false, studioRequested:true))
        XCTAssertTrue(HelperStartupPolicy.shouldStayRunning(startAtLogin:true, studioRequested:true))
    }
    func testResumeRequiresLoginEnabledPreviousIntentAndConfiguration() {
        for enabled in [false,true] { for running in [false,true] { for configured in [false,true] {
            XCTAssertEqual(HelperStartupPolicy.shouldResume(startAtLogin:enabled, wasRunning:running, configured:configured), enabled && running && configured)
        } } }
    }
    private func attempt(pending:Bool=true, wantsOn:Bool=false, lostKeyboard:Bool=false,
                         boardPresent:Bool=true, permissionsGranted:Bool=true,
                         active:Bool=false, busy:Bool=false, failures:Int=0,
                         lastAttempt:TimeInterval?=nil, now:TimeInterval=1000) -> Bool {
        HelperStartupPolicy.shouldAttemptResume(pending:pending,wantsOn:wantsOn,lostKeyboard:lostKeyboard,
            boardPresent:boardPresent,permissionsGranted:permissionsGranted,active:active,busy:busy,
            failures:failures,lastAttempt:lastAttempt,now:now)
    }
    func testResumeRequiresBoardAndPermissionsForBothLoginAndUSBReturn() {
        for pending in [false,true] {
            for present in [false,true] { for allowed in [false,true] {
                XCTAssertEqual(attempt(pending:pending,wantsOn:!pending,lostKeyboard:!pending,
                    boardPresent:present,permissionsGranted:allowed),present && allowed)
            } }
        }
    }
    func testResumeRequiresIntentAndIdleCapture() {
        XCTAssertFalse(attempt(pending:false))
        XCTAssertFalse(attempt(pending:false,wantsOn:true))
        XCTAssertFalse(attempt(pending:false,lostKeyboard:true))
        XCTAssertFalse(attempt(active:true))
        XCTAssertFalse(attempt(busy:true))
        XCTAssertTrue(attempt())
        XCTAssertTrue(attempt(pending:false,wantsOn:true,lostKeyboard:true))
    }
    func testFailedResumeBacksOffFromFifteenSecondsToFiveMinutes() {
        for (failures,delay) in [(1,15.0),(2,30.0),(3,60.0),(4,120.0),(5,240.0),(6,300.0),(100,300.0)] {
            XCTAssertFalse(attempt(failures:failures,lastAttempt:1000,now:1000+delay-0.01))
            XCTAssertTrue(attempt(failures:failures,lastAttempt:1000,now:1000+delay))
        }
        XCTAssertFalse(attempt(pending:false,wantsOn:true,lostKeyboard:true,
            failures:1,lastAttempt:1000,now:1003))
    }
    func testFreshResumeIsImmediateAndStoppedResumeNeverRetries() {
        XCTAssertTrue(attempt(lastAttempt:1000,now:1000))
        XCTAssertTrue(attempt(failures:6,lastAttempt:nil))
        XCTAssertFalse(attempt(pending:false,failures:6,lastAttempt:0,now:10000))
        XCTAssertFalse(attempt(failures:1,lastAttempt:1000,now:999))
    }

    func testRegistrationRefreshesOnceForEachBuild() {
        XCTAssertTrue(HelperStartupPolicy.shouldRefreshRegistration(currentBuild:"21",registeredBuild:nil))
        XCTAssertTrue(HelperStartupPolicy.shouldRefreshRegistration(currentBuild:"21",registeredBuild:"20"))
        XCTAssertFalse(HelperStartupPolicy.shouldRefreshRegistration(currentBuild:"21",registeredBuild:"21"))
        XCTAssertTrue(HelperStartupPolicy.shouldRefreshRegistration(currentBuild:"20",registeredBuild:"21"))
        XCTAssertFalse(HelperStartupPolicy.shouldRefreshRegistration(currentBuild:nil,registeredBuild:nil))
    }
    func testBackoffResetsOnlyOnBoardOrPermissionArrival() {
        for previousBoard in [false,true] { for board in [false,true] {
            for previousPermissions in [false,true] { for permissions in [false,true] {
                XCTAssertEqual(HelperStartupPolicy.shouldResetResumeBackoff(
                    previousBoardPresent:previousBoard,boardPresent:board,
                    previousPermissionsGranted:previousPermissions,permissionsGranted:permissions),
                    (!previousBoard && board) || (!previousPermissions && permissions))
            } }
        } }
    }
    func testVialBlocksAutomaticResumeEvenAfterBackoffExpires() {
        for pending in [false,true] {
            XCTAssertFalse(HelperStartupPolicy.shouldAttemptResume(pending:pending,wantsOn:!pending,lostKeyboard:!pending,
                boardPresent:true,permissionsGranted:true,active:false,busy:false,vialRunning:true,
                failures:0,lastAttempt:nil,now:1000))
            XCTAssertFalse(HelperStartupPolicy.shouldAttemptResume(pending:pending,wantsOn:!pending,lostKeyboard:!pending,
                boardPresent:true,permissionsGranted:true,active:false,busy:false,vialRunning:true,
                failures:6,lastAttempt:0,now:1000))
            XCTAssertTrue(HelperStartupPolicy.shouldAttemptResume(pending:pending,wantsOn:!pending,lostKeyboard:!pending,
                boardPresent:true,permissionsGranted:true,active:false,busy:false,vialRunning:false,
                failures:0,lastAttempt:nil,now:1003))
        }
    }

}
