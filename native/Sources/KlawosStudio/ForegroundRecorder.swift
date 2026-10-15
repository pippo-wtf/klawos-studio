import Cocoa
import KlawosContracts
@MainActor final class ForegroundRecorder {
    let core=MacroRecorderCore();var monitor:Any?;var modifiers:Set<UInt16>=[]
    func start(){stop();core.start();modifiers=[]
        monitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.keyUp,.flagsChanged]){[weak self] event in
            let consumed=MainActor.assumeIsolated {
                guard let self,self.core.active else{return false}
                if event.keyCode==53 && event.type == .keyDown{self.stop();return true}
                if event.type == .flagsChanged {
                    if Self.flag(for:event.keyCode) != nil,let code=MacKeycodes.qmk[event.keyCode]{
                        let down = !self.modifiers.contains(event.keyCode)
                        if down{self.modifiers.insert(event.keyCode)}else{self.modifiers.remove(event.keyCode)}
                        self.core.record(code:code,down:down,time:event.timestamp)
                    }else{self.syncModifiers(event.modifierFlags,time:event.timestamp)}
                }else if !event.isARepeat{
                    self.syncModifiers(event.modifierFlags,time:event.timestamp)
                    if let code=MacKeycodes.qmk[event.keyCode]{self.core.record(code:code,down:event.type == .keyDown,time:event.timestamp)}
                }
                return true
            }
            return consumed ? nil:event
        }
    }
    func stop(){core.stop();if let monitor{NSEvent.removeMonitor(monitor)};monitor=nil;modifiers=[]}
    private static func flag(for key:UInt16)->NSEvent.ModifierFlags?{
        switch key{case 59,62:return .control;case 58,61:return .option;case 56,60:return .shift;case 54,55:return .command;default:return nil}
    }
    private func syncModifiers(_ flags:NSEvent.ModifierFlags,time:TimeInterval){
        for (flag,keys) in [(NSEvent.ModifierFlags.control,[UInt16(59),62]),(.option,[58,61]),(.shift,[56,60]),(.command,[55,54])]{
            let held=keys.filter{modifiers.contains($0)}
            if flags.contains(flag),held.isEmpty,let key=keys.first,let code=MacKeycodes.qmk[key]{modifiers.insert(key);core.record(code:code,down:true,time:time)}
            if !flags.contains(flag){for key in held{modifiers.remove(key);if let code=MacKeycodes.qmk[key]{core.record(code:code,down:false,time:time)}}}
        }
    }
    func state()->[String:Any]{let data=(try? JSONEncoder().encode(core.events)) ?? Data("[]".utf8);return ["active":core.active,"events":(try? JSONSerialization.jsonObject(with:data)) ?? [],"eventCount":core.events.count]}
}
