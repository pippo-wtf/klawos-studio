import Foundation
public enum Diagnostics {
    public static func redacted(_ state:DiagnosticState)->JSONObject {
        var result:JSONObject=["version":.string("0.1.12"),"formatVersion":.integer(1),"buildKind":.string("local-development")]
        if case .object(let permissions)=state["permissions"] {
            var safe:JSONObject=[:];for key in ["accessibility","inputMonitoring"]{if case .bool(let value)=permissions[key]{safe[key] = .bool(value)}};result["permissions"] = .object(safe)
        }
        if case .object(let capabilities)=state["capabilities"] {
            var safe:JSONObject=[:];for key in ["layers","rows","cols","encoders","macroSlots","macroBytes","tapDanceSlots","comboSlots","keyOverrideSlots","altRepeatSlots"]{if case .integer(let value)=capabilities[key],value>=0,value<=65535{safe[key] = .integer(value)}};result["capabilities"] = .object(safe)
        }
        if case .string(let helper)=state["helperState"],["running","paused","stopped","unavailable"].contains(helper){result["helperState"] = .string(helper)}
        return result
    }
}
