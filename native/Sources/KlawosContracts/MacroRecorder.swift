import Foundation
/// Receives only explicit foreground recording events. No background or diagnostic storage.
public final class MacroRecorderCore {
    public private(set) var active=false
    public private(set) var events:[JSONValue]=[]
    private var held:Set<String>=[];private var lastTime:TimeInterval?
    public init(){}
    public func start(heldModifiers:Set<UInt16>=[],time:TimeInterval=0){
        events=[];held=[];lastTime=nil;active=true
        synchronizeModifiers(heldModifiers,time:time)
    }
    public func synchronizeModifiers(_ keyCodes:Set<UInt16>,time:TimeInterval){
        for key in MacKeycodes.modifiers {
            if let code=MacKeycodes.qmk[key]{record(code:code,down:keyCodes.contains(key),time:time)}
        }
    }
    public func record(code:String,down:Bool,time:TimeInterval){
        guard active else{return}
        if down ? held.contains(code):!held.contains(code){return}
        if events.count>=4000{_ = stop();return}
        if let lastTime {let delay=Int(max(0,min(65024,(time-lastTime)*1000)));if delay>=10{events.append(.array([.string("delay"),.integer(Int64(delay))]))}}
        lastTime=time
        events.append(.array([.string(down ? "down":"up"),.string(code)]))
        if down{held.insert(code)}else{held.remove(code)}
    }
    @discardableResult public func stop()->[JSONValue]{
        guard active else{return events};active=false
        for code in held.sorted(){events.append(.array([.string("up"),.string(code)]))};held=[];return events
    }
}
public enum MacKeycodes {
    public static let modifiers:[UInt16]=[54,55,56,58,59,60,61,62]
    public static let qmk:[UInt16:String]=[0:"KC_A",1:"KC_S",2:"KC_D",3:"KC_F",4:"KC_H",5:"KC_G",6:"KC_Z",7:"KC_X",8:"KC_C",9:"KC_V",10:"KC_NUBS",11:"KC_B",12:"KC_Q",13:"KC_W",14:"KC_E",15:"KC_R",16:"KC_Y",17:"KC_T",18:"KC_1",19:"KC_2",20:"KC_3",21:"KC_4",22:"KC_6",23:"KC_5",24:"KC_EQL",25:"KC_9",26:"KC_7",27:"KC_MINS",28:"KC_8",29:"KC_0",30:"KC_RBRC",31:"KC_O",32:"KC_U",33:"KC_LBRC",34:"KC_I",35:"KC_P",36:"KC_ENT",37:"KC_L",38:"KC_J",39:"KC_QUOT",40:"KC_K",41:"KC_SCLN",42:"KC_BSLS",43:"KC_COMM",44:"KC_SLSH",45:"KC_N",46:"KC_M",47:"KC_DOT",48:"KC_TAB",49:"KC_SPC",50:"KC_GRV",51:"KC_BSPC",53:"KC_ESC",54:"KC_RGUI",55:"KC_LGUI",56:"KC_LSFT",57:"KC_CAPS",58:"KC_LALT",59:"KC_LCTL",60:"KC_RSFT",61:"KC_RALT",62:"KC_RCTL",64:"KC_F17",65:"KC_PDOT",67:"KC_PAST",69:"KC_PPLS",71:"KC_NUM",75:"KC_PSLS",76:"KC_PENT",78:"KC_PMNS",79:"KC_F18",80:"KC_F19",81:"KC_PEQL",82:"KC_P0",83:"KC_P1",84:"KC_P2",85:"KC_P3",86:"KC_P4",87:"KC_P5",88:"KC_P6",89:"KC_P7",90:"KC_F20",91:"KC_P8",92:"KC_P9",96:"KC_F5",97:"KC_F6",98:"KC_F7",99:"KC_F3",100:"KC_F8",101:"KC_F9",103:"KC_F11",105:"KC_F13",106:"KC_F16",107:"KC_F14",109:"KC_F10",111:"KC_F12",113:"KC_F15",114:"KC_INS",115:"KC_HOME",116:"KC_PGUP",117:"KC_DEL",118:"KC_F4",119:"KC_END",120:"KC_F2",121:"KC_PGDN",122:"KC_F1",123:"KC_LEFT",124:"KC_RGHT",125:"KC_DOWN",126:"KC_UP"]
}
