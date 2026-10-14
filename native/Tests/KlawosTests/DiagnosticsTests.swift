import XCTest
@testable import KlawosContracts
final class DiagnosticsTests:XCTestCase {
    func testNoUserContentOrUnboundedUpstreamStrings() throws {
        let secret="seeded-private-macro-home-token"
        let state:JSONObject=["version":.string(secret),"macro":.string(secret),"error":.string(secret),"path":.string(secret),"permissions":.object(["accessibility":.bool(true),"inputMonitoring":.bool(false),"secret":.string(secret)]),"capabilities":.object(["layers":.integer(6),"raw":.string(secret)]),"helperState":.string("running")]
        let text=String(data:try JSONEncoder().encode(Diagnostics.redacted(state)),encoding:.utf8)!
        XCTAssertFalse(text.contains(secret));XCTAssertTrue(text.contains("accessibility"));XCTAssertTrue(text.contains("layers"))
    }
}
