import XCTest
import Carbon
@testable import KlawosContracts

final class RecordingInputProtectionTests:XCTestCase {
    @MainActor func testSecureInputCoversHotkeyPauseAndRestoresPreviousOwner() {
        var secureCount=1,hotkeysPaused=false
        let token=UnsafeMutableRawPointer(bitPattern:1)!
        let cleanup=RecordingInputProtection.acquire(
            enable:{secureCount += 1;return noErr},disable:{secureCount -= 1;return noErr},
            pause:{XCTAssertEqual(secureCount,2);hotkeysPaused=true;return token},
            resume:{XCTAssertEqual($0,token);XCTAssertEqual(secureCount,2);hotkeysPaused=false})
        XCTAssertNotNil(cleanup);XCTAssertTrue(hotkeysPaused);XCTAssertEqual(secureCount,2)
        cleanup?()
        XCTAssertFalse(hotkeysPaused);XCTAssertEqual(secureCount,1,"Never disable another owner's secure input")
    }
    @MainActor func testFailedHotkeyPauseBalancesSecureInput() {
        var secureCount=0
        let cleanup=RecordingInputProtection.acquire(
            enable:{secureCount += 1;return noErr},disable:{secureCount -= 1;return noErr},
            pause:{nil},resume:{_ in XCTFail("No token was acquired")})
        XCTAssertNil(cleanup);XCTAssertEqual(secureCount,0)
    }
    @MainActor func testFailedSecureInputCannotStartUnprotectedRecording() {
        var attemptedPause=false,disabled=false
        let cleanup=RecordingInputProtection.acquire(
            enable:{-1},disable:{disabled=true;return noErr},
            pause:{attemptedPause=true;return UnsafeMutableRawPointer(bitPattern:1)},resume:{_ in})
        XCTAssertNil(cleanup);XCTAssertFalse(attemptedPause);XCTAssertFalse(disabled)
    }
}
