import XCTest
import AppKit
@testable import KlawosContracts

final class RecorderModifiersTests:XCTestCase {
    func testQueuedRapidChordUsesHistoricalSideEvents() {
        var modifiers=RecorderModifiers(heldKeys:[])
        let core=MacroRecorderCore();core.start()
        XCTAssertTrue(modifiers.update(keyCode:62,flags:[.control],isFlagsChanged:true))
        core.synchronizeModifiers(modifiers.keys,time:0)
        XCTAssertTrue(modifiers.update(keyCode:61,flags:[.control,.option],isFlagsChanged:true))
        core.synchronizeModifiers(modifiers.keys,time:0)
        XCTAssertTrue(modifiers.update(keyCode:11,flags:[.control,.option],isFlagsChanged:false))
        core.synchronizeModifiers(modifiers.keys,time:0)
        core.record(code:"KC_B",down:true,time:0)
        XCTAssertTrue(modifiers.update(keyCode:61,flags:[.control],isFlagsChanged:true))
        core.synchronizeModifiers(modifiers.keys,time:0)
        XCTAssertTrue(modifiers.update(keyCode:62,flags:[],isFlagsChanged:true))
        core.synchronizeModifiers(modifiers.keys,time:0)
        XCTAssertEqual(core.events,[
            .array([.string("down"),.string("KC_RCTL")]),
            .array([.string("down"),.string("KC_RALT")]),
            .array([.string("down"),.string("KC_B")]),
            .array([.string("up"),.string("KC_RALT")]),
            .array([.string("up"),.string("KC_RCTL")])])
    }
    func testPreheldRightSideSurvivesMainKeyAndLeftRightRelease() {
        var modifiers=RecorderModifiers(heldKeys:[59,62])
        XCTAssertTrue(modifiers.update(keyCode:11,flags:[.control],isFlagsChanged:false))
        XCTAssertEqual(modifiers.keys,[59,62])
        XCTAssertTrue(modifiers.update(keyCode:62,flags:[.control],isFlagsChanged:true))
        XCTAssertEqual(modifiers.keys,[59])
        XCTAssertTrue(modifiers.update(keyCode:59,flags:[],isFlagsChanged:true))
        XCTAssertEqual(modifiers.keys,[])
    }
    func testUnknownSideFailsClosedInsteadOfInferringLeft() {
        var modifiers=RecorderModifiers(heldKeys:[])
        XCTAssertFalse(modifiers.update(keyCode:11,flags:[.option],isFlagsChanged:false))
        XCTAssertEqual(modifiers.keys,[])
    }
}
