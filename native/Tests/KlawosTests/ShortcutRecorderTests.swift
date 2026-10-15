import XCTest
import AppKit
@testable import KlawosContracts

final class ShortcutRecorderTests: XCTestCase {
    @MainActor func testRegisteredLeftControlOptionDIsConsumedAndRecorded() throws {
        var restored=0
        let recorder=ShortcutRecorder(trusted:{true},frontmost:{true},now:{0},held:{[]},install:{_ in {restored += 1}})
        try recorder.start()
        for (type,key,flags) in [(CGEventType.flagsChanged,UInt16(59),CGEventFlags.maskControl),
                                (.flagsChanged,58,[.maskControl,.maskAlternate]),
                                (.keyDown,2,[.maskControl,.maskAlternate]),
                                (.keyUp,2,[.maskControl,.maskAlternate])] {
            let event=CGEvent(keyboardEventSource:nil,virtualKey:key,keyDown:type == .keyDown)!
            event.flags=flags;event.timestamp=0
            XCTAssertNil(recorder.process(type:type,event:event),"Recording must prevent downstream shortcuts from seeing the chord")
        }
        recorder.stop();recorder.stop()
        XCTAssertEqual(restored,1)
        XCTAssertEqual(recorder.core.events,[
            .array([.string("down"),.string("KC_LCTL")]),.array([.string("down"),.string("KC_LALT")]),
            .array([.string("down"),.string("KC_D")]),.array([.string("up"),.string("KC_D")]),
            .array([.string("up"),.string("KC_LALT")]),.array([.string("up"),.string("KC_LCTL")])])
        let event=CGEvent(keyboardEventSource:nil,virtualKey:2,keyDown:true)!
        XCTAssertNotNil(recorder.process(type:.keyDown,event:event))
    }
    @MainActor func testPreheldModifiersAreSampledBeforeSecureInputBlocksKeyState() throws {
        var protected=false
        let recorder=ShortcutRecorder(trusted:{true},frontmost:{true},now:{0},
            held:{protected ? []:[62,61]},install:{_ in protected=true;return {protected=false}})
        try recorder.start()
        XCTAssertEqual(recorder.core.events,[
            .array([.string("down"),.string("KC_RALT")]),
            .array([.string("down"),.string("KC_RCTL")])])
        recorder.stop()
        XCTAssertFalse(protected)
    }
    @MainActor func testUntrustedRecordingFailsBeforeInstallingAnything() {
        var installed=false
        let recorder=ShortcutRecorder(trusted:{false},frontmost:{true},now:{0},held:{[]},install:{_ in installed=true;return {}})
        XCTAssertThrowsError(try recorder.start())
        XCTAssertFalse(installed);XCTAssertFalse(recorder.core.active)
    }
    @MainActor func testFocusLossTimeoutAndPermissionLossRestoreShortcuts() throws {
        for cause in ["focus","timeout","permission"] {
            var frontmost=true, trusted=true, time:TimeInterval=0, restored=0
            let recorder=ShortcutRecorder(trusted:{trusted},frontmost:{frontmost},now:{time},held:{[]},install:{_ in {restored += 1}})
            try recorder.start()
            if cause=="focus" {frontmost=false}
            if cause=="permission" {trusted=false}
            if cause=="timeout" {time=36}
            recorder.checkSession()
            XCTAssertFalse(recorder.core.active,cause);XCTAssertEqual(restored,1,cause)
        }
    }
    @MainActor func testEscapeAndUnknownModifierRestoreShortcuts() throws {
        for escape in [true,false] {
            var restored=0
            let recorder=ShortcutRecorder(trusted:{true},frontmost:{true},now:{0},held:{[]},install:{_ in {restored += 1}})
            try recorder.start()
            let event=CGEvent(keyboardEventSource:nil,virtualKey:escape ? 53:2,keyDown:true)!
            event.flags=escape ? []:[.maskAlternate]
            _=recorder.process(type:.keyDown,event:event)
            XCTAssertFalse(recorder.core.active);XCTAssertEqual(restored,1)
        }
    }
    @MainActor func testCannotStartWithoutFilterOrWhileInBackground() {
        let failed=ShortcutRecorder(trusted:{true},frontmost:{true},now:{0},held:{[]},install:{_ in nil})
        XCTAssertThrowsError(try failed.start());XCTAssertFalse(failed.core.active)
        var installed=false
        let background=ShortcutRecorder(trusted:{true},frontmost:{false},now:{0},held:{[]},install:{_ in installed=true;return {}})
        XCTAssertThrowsError(try background.start());XCTAssertFalse(installed)
    }
    @MainActor func testRestartAndReleaseCleanUpEverySession() throws {
        var restored=0
        var recorder:ShortcutRecorder?=ShortcutRecorder(trusted:{true},frontmost:{true},now:{0},held:{[]},install:{_ in {restored += 1}})
        try recorder!.start();try recorder!.start()
        XCTAssertEqual(restored,1)
        recorder=nil
        XCTAssertEqual(restored,2)
    }
}
