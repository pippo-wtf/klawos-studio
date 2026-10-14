import Cocoa
import KlawosContracts
struct SavedHelper:Codable {
    let configuration:HelperConfiguration
    let allocations:[InputID:String]
    let uid:String
}
@MainActor final class HelperRuntime {
    let capture=LiveInputCapture();let executor=ActionExecutor()
    var saved:SavedHelper?;var lastResult="";var inFlight=0
    let file=AgentPaths.directory.appendingPathComponent("helper.json")
    init(){saved=(try? Data(contentsOf:file)).flatMap{try? JSONDecoder().decode(SavedHelper.self,from:$0)}
        capture.onPress={[weak self] token in
            guard let self,self.inFlight<4 else{return};self.inFlight+=1
            let generation=self.saved?.configuration.generation
            Task{@MainActor in
                defer{self.inFlight-=1}
                guard self.capture.active,self.saved?.configuration.generation==generation,NSWorkspace.shared.frontmostApplication?.bundleIdentifier==token.context.frontmostBundleID else{return}
                let result=await self.executor.execute(token.binding.action);self.lastResult=result.state=="executed" ? "Action completed":result.reason
            }
        }
    }
    func status()->[String:Any]{["state":capture.active ? "running":"stopped","reason":capture.reason,"permissions":InputTapController.permissions,"configuredInputs":saved?.allocations.count ?? 0,"lastResult":lastResult,"presses":capture.presses,"releases":capture.releases]}
    func stop(){capture.stop()}
    func install(profiles:Any,snapshot:Snapshot,allocations:[InputID:String])throws {
        capture.stop(reason:"Configuration changed. Start to revalidate.")
        let value:[String:Any]=["generation":UUID().uuidString,"triggerMapRevision":snapshot.revision,"bindings":profiles]
        let config=try JSONDecoder().decode(HelperConfiguration.self,from:JSONSerialization.data(withJSONObject:value))
        let next=SavedHelper(configuration:config,allocations:allocations,uid:snapshot.identity.uid)
        let data=try JSONEncoder().encode(next);try DurableFile.write(data,to:file);saved=next
    }
    func start(snapshot:Snapshot)throws {
        guard let saved,!saved.allocations.isEmpty,saved.uid==snapshot.identity.uid,saved.configuration.triggerMapRevision==snapshot.revision,
              case .object(let descriptor)=snapshot.metadata["descriptor"],case .string(let token)=descriptor["pathToken"] else{throw InputRoutingError.unverifiedConfiguration}
        let plan=try TriggerAllocator().allocate(snapshot:snapshot,helperInputs:Array(saved.allocations.keys))
        guard plan.allocations==saved.allocations else{throw InputRoutingError.unverifiedConfiguration}
        guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="today.vial"}) else{throw InputRoutingError.unverifiedConfiguration}
        try capture.start(allocations:saved.allocations,configuration:saved.configuration,deviceToken:token)
    }
    static func prepare(_ payload:[String:Any])throws->([String:Any],[InputID:String]) {
        let profiles=payload["profiles"] as? [String:Any] ?? [:]
        if profiles.isEmpty{return(payload,[:])}
        guard let base=payload["base"],let proposed=payload["hardware"] as? [String:Any],let initialLayers=proposed["layout"] as? [[[Any]]] else{throw ActionValidationError.invalidParameters}
        let baseline=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:base))
        var snapshot=baseline
        snapshot.hardware=try JSONDecoder().decode(JSONObject.self,from:JSONSerialization.data(withJSONObject:proposed))
        for value in profiles.values{
            let bindings=try JSONDecoder().decode(ContextBindings.self,from:JSONSerialization.data(withJSONObject:value))
            _ = try ContextRouter.resolve(bundleID:nil,bindings:bindings)
            if case .object(let overrides)=bindings["overrides"]{for id in overrides.keys{_ = try ContextRouter.resolve(bundleID:id,bindings:bindings)}}
        }
        let plan=try TriggerAllocator().allocate(snapshot:snapshot,helperInputs:Array(profiles.keys))
        var hardware=proposed
        var layers=initialLayers
        for (input,code) in plan.allocations {let p=input.split(separator:":");layers[0][Int(p[1])!][Int(p[2])!]=code}
        hardware["layout"]=layers
        var result=payload;result["hardware"]=hardware
        return(result,plan.allocations)
    }
}
