import XCTest
@testable import KlawosContracts
final class MacroRecorderTests:XCTestCase {
    func testExplicitStartStopAndHeldRelease() {
        let recorder=MacroRecorderCore();recorder.record(code:"KC_A",down:true,time:0)
        XCTAssertTrue(recorder.events.isEmpty)
        recorder.start();recorder.record(code:"KC_A",down:true,time:1)
        recorder.record(code:"KC_A",down:true,time:1.1)
        let events=recorder.stop();XCTAssertEqual(events,[.array([.string("down"),.string("KC_A")]),.array([.string("up"),.string("KC_A")])])
        recorder.record(code:"KC_B",down:true,time:2);XCTAssertEqual(recorder.events,events)
    }
    func testDelaysAndBalancedKeys() {
        let recorder=MacroRecorderCore();recorder.start();recorder.record(code:"KC_A",down:true,time:1);recorder.record(code:"KC_A",down:false,time:1.1)
        XCTAssertEqual(recorder.stop().count,3)
    }
}
