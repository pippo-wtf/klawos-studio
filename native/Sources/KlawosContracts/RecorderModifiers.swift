import AppKit

public struct RecorderModifiers {
    public private(set) var keys:Set<UInt16>
    private static let groups:[(NSEvent.ModifierFlags,[UInt16])]=[
        (.control,[59,62]),(.option,[58,61]),(.shift,[56,60]),(.command,[55,54])]
    public init(heldKeys:Set<UInt16>){keys=heldKeys.intersection(MacKeycodes.modifiers)}
    public mutating func update(keyCode:UInt16,flags:NSEvent.ModifierFlags,isFlagsChanged:Bool)->Bool {
        if isFlagsChanged,let (flag,_)=Self.groups.first(where:{$0.1.contains(keyCode)}),flags.contains(flag) {
            if keys.contains(keyCode){keys.remove(keyCode)}else{keys.insert(keyCode)}
        }
        for (flag,group) in Self.groups {
            if !flags.contains(flag){keys.subtract(group)}
            else if keys.isDisjoint(with:group){return false}
        }
        return true
    }
}
