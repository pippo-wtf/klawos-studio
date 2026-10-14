import XCTest
@testable import KlawosContracts
final class ContextRouterTests:XCTestCase {
    let bindings:JSONObject=["default":.object(["kind":.string("openApp"),"parameters":.object(["bundleID":.string("com.apple.TextEdit")])]),"overrides":.object(["com.anthropic.claudefordesktop":.object(["kind":.string("none"),"parameters":.object([:])])])]
    func testExactContextAndExplicitNone() throws {
        XCTAssertEqual(try ContextRouter.resolve(bundleID:"com.anthropic.claudefordesktop",bindings:bindings).action.kind,"none")
        XCTAssertEqual(try ContextRouter.resolve(bundleID:"com.anthropic.claudefordesktop.fake",bindings:bindings).action.kind,"openApp")
    }
    func testHeldPressFreezesContext() throws {
        let router=ContextRouter()
        let token=try router.beginPress(input:"key:0:0",bundleID:"com.apple.finder",bindings:bindings)
        XCTAssertEqual(token.binding.action.kind,"openApp")
        XCTAssertThrowsError(try router.beginPress(input:"key:0:0",bundleID:"com.anthropic.claudefordesktop",bindings:bindings))
        XCTAssertEqual(router.endPress(input:"key:0:0")?.id,token.id)
        XCTAssertNil(router.endPress(input:"key:0:0"))
    }
    func testUntrustedActionKindsAndFieldsRejected() {
        XCTAssertThrowsError(try ActionValidator.validate(ActionDescriptor(kind:"shell",id:nil,parameters:["command":.string("echo bad")])))
        XCTAssertThrowsError(try ActionValidator.validate(ActionDescriptor(kind:"shortcut",id:nil,parameters:["keyCode":.integer(999),"modifiers":.array([])])))
    }
}
