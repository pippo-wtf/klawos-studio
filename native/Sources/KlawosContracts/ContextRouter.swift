import Foundation
public enum ActionValidationError:Error { case unsupportedAction,invalidParameters,alreadyHeld }
public enum ActionValidator {
    public static func validate(_ action:ActionDescriptor)throws {
        let p=action.parameters
        switch action.kind {
        case "none":guard p.isEmpty else {throw ActionValidationError.invalidParameters}
        case "openApp":
            guard Set(p.keys)==["bundleID"],case .string(let id)=p["bundleID"],!id.isEmpty,id.count<=255,id.range(of:"^[A-Za-z0-9.-]+$",options:.regularExpression) != nil else {throw ActionValidationError.invalidParameters}
        case "shortcut":
            guard Set(p.keys)==["keyCode","modifiers"],case .integer(let key)=p["keyCode"],key>=0,key<=127,
                  case .array(let mods)=p["modifiers"],mods.count<=4,mods.allSatisfy({[JSONValue.string("command"),.string("control"),.string("option"),.string("shift")].contains($0)}) else {throw ActionValidationError.invalidParameters}
        case "namedShortcut":
            guard Set(p.keys)==["name"],case .string(let name)=p["name"],!name.isEmpty,name.count<=256,!name.contains("\0"),!name.hasPrefix("-") else {throw ActionValidationError.invalidParameters}
        case "menuCommand":
            guard Set(p.keys)==["bundleID","menuPath"],case .string(let bundle)=p["bundleID"],!bundle.isEmpty,
                  case .array(let path)=p["menuPath"],path.count>=2,path.count<=6,path.allSatisfy({if case .string(let title)=$0{return !title.isEmpty && title.count<200};return false}) else {throw ActionValidationError.invalidParameters}
        default:throw ActionValidationError.unsupportedAction
        }
    }
}
public final class ContextRouter {
    private var held:[InputID:PressToken]=[:]
    public init(){}
    public static func resolve(bundleID:String?,bindings:ContextBindings)throws->ResolvedBinding {
        var selected=bindings["default"] ?? .object(["kind":.string("none"),"parameters":.object([:])]);var inherited=true
        if let bundleID,case .object(let overrides)=bindings["overrides"],let override=overrides[bundleID]{selected=override;inherited=false}
        let action=try JSONDecoder().decode(ActionDescriptor.self,from:JSONEncoder().encode(selected));try ActionValidator.validate(action)
        return ResolvedBinding(profileID:inherited ? "default":bundleID!,inherited:inherited,action:action)
    }
    public func beginPress(input:InputID,bundleID:String?,bindings:ContextBindings)throws->PressToken {
        guard held[input]==nil else {throw ActionValidationError.alreadyHeld}
        let binding=try Self.resolve(bundleID:bundleID,bindings:bindings)
        let context=ContextSnapshot(frontmostBundleID:bundleID,lastExternalBundleID:nil,resolvedProfile:binding.profileID,helperState:"running",permissions:[:])
        let token=PressToken(id:UUID(),input:input,context:context,binding:binding);held[input]=token;return token
    }
    public func endPress(input:InputID)->PressToken?{held.removeValue(forKey:input)}
    public func releaseAll(){held.removeAll()}
}
