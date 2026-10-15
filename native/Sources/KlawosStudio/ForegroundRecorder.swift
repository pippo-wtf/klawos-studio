import Cocoa
@preconcurrency import ApplicationServices
import KlawosContracts
@MainActor final class ForegroundRecorder {
    private let capture=ShortcutRecorder()
    var core:MacroRecorderCore{capture.core}
    func start(captureEscape:Bool=false) throws {
        do{try capture.start(captureEscape:captureEscape)}
        catch RecordingError.permissionRequired {
            let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
            _=AXIsProcessTrustedWithOptions(options)
            throw RecordingError.permissionRequired
        }
    }
    func stop(){capture.stop()}
    func state()->[String:Any]{capture.checkSession();let data=(try? JSONEncoder().encode(core.events)) ?? Data("[]".utf8);return ["active":core.active,"events":(try? JSONSerialization.jsonObject(with:data)) ?? [],"eventCount":core.events.count]}
}
