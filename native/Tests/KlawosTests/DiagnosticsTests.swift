import XCTest
@testable import KlawosContracts
final class DiagnosticsTests:XCTestCase {
    func testNoUserContentOrUnboundedUpstreamStrings() throws {
        let secret="seeded-private-macro-home-token"
        let state:JSONObject=["version":.string(secret),"macro":.string(secret),"error":.string(secret),"path":.string(secret),"permissions":.object(["accessibility":.bool(true),"inputMonitoring":.bool(false),"secret":.string(secret)]),"capabilities":.object(["layers":.integer(6),"raw":.string(secret)]),"helperState":.string("running")]
        let text=String(data:try JSONEncoder().encode(Diagnostics.redacted(state)),encoding:.utf8)!
        XCTAssertFalse(text.contains(secret));XCTAssertTrue(text.contains("accessibility"));XCTAssertTrue(text.contains("layers"))
    }
    func testPausedStateSurvivesWhilePrivateFieldsStayRedacted() throws {
        let secret = "private-name-profile-path"
        let result = Diagnostics.redacted(["helperState": .string("paused"), "profile": .string(secret), "lastResult": .string(secret), "path": .string(secret)])
        XCTAssertEqual(result["helperState"], .string("paused"))
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(result), as: UTF8.self).contains(secret))
        XCTAssertNil(result["profile"])
        XCTAssertNil(result["lastResult"])
        XCTAssertNil(result["path"])
    }

}
