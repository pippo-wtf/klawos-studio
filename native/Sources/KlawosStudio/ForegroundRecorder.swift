import Cocoa
import KlawosContracts
@MainActor final class ForegroundRecorder {
    let core=MacroRecorderCore();var monitor:Any?;var modifiers=RecorderModifiers(heldKeys:[])
    private static func heldModifiers()->Set<UInt16>{
        Set(MacKeycodes.modifiers.filter{CGEventSource.keyState(.combinedSessionState,key:$0)})
    }
    func start(){stop();modifiers=RecorderModifiers(heldKeys:Self.heldModifiers())
        core.start(heldModifiers:modifiers.keys,time:ProcessInfo.processInfo.systemUptime)
        monitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.keyUp,.flagsChanged]){[weak self] event in
            let consumed=MainActor.assumeIsolated {
                guard let self,self.core.active else{return false}
                if event.keyCode==53 && event.type == .keyDown{self.stop();return true}
                guard self.modifiers.update(keyCode:event.keyCode,flags:event.modifierFlags,isFlagsChanged:event.type == .flagsChanged) else{self.stop();return true}
                self.core.synchronizeModifiers(self.modifiers.keys,time:event.timestamp)
                if event.type != .flagsChanged && !event.isARepeat,
                   let code=MacKeycodes.qmk[event.keyCode]{self.core.record(code:code,down:event.type == .keyDown,time:event.timestamp)}
                return true
            }
            return consumed ? nil:event
        }
    }
    func stop(){core.stop();if let monitor{NSEvent.removeMonitor(monitor)};monitor=nil;modifiers=RecorderModifiers(heldKeys:[])}
    func state()->[String:Any]{let data=(try? JSONEncoder().encode(core.events)) ?? Data("[]".utf8);return ["active":core.active,"events":(try? JSONSerialization.jsonObject(with:data)) ?? [],"eventCount":core.events.count]}
}
