import Cocoa
import KlawosContracts
@MainActor final class ForegroundRecorder {
    let core=MacroRecorderCore();var monitor:Any?;var modifiers:Set<UInt16>=[]
    func start(){stop();core.start();modifiers=[]
        monitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.keyUp,.flagsChanged]){[weak self] event in
            let consumed=MainActor.assumeIsolated {
                guard let self,self.core.active else{return false}
                if event.keyCode==53 && event.type == .keyDown{self.stop();return true}
                guard let code=MacKeycodes.qmk[event.keyCode] else{return true}
                if event.type == .flagsChanged {
                    let down = !self.modifiers.contains(event.keyCode)
                    if down{self.modifiers.insert(event.keyCode)}else{self.modifiers.remove(event.keyCode)}
                    self.core.record(code:code,down:down,time:event.timestamp)
                }else if !event.isARepeat{self.core.record(code:code,down:event.type == .keyDown,time:event.timestamp)}
                return true
            }
            return consumed ? nil:event
        }
    }
    func stop(){core.stop();if let monitor{NSEvent.removeMonitor(monitor)};monitor=nil;modifiers=[]}
    func state()->[String:Any]{let data=(try? JSONEncoder().encode(core.events)) ?? Data("[]".utf8);return ["active":core.active,"events":(try? JSONSerialization.jsonObject(with:data)) ?? [],"eventCount":core.events.count]}
}
