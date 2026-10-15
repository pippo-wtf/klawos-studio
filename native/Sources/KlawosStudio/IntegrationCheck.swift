import Foundation
import ApplicationServices
import ServiceManagement
import KlawosContracts
@MainActor func integrationCheck() {
    Task {
        do{
            if CommandLine.arguments.contains("--reset-agent-registration") || CommandLine.arguments.contains("--refresh-helper-registration") {
                let registration=SMAppService.agent(plistName:"com.pippo.klawos.agent.plist")
                if registration.status != .notRegistered && registration.status != .notFound {try await registration.unregister()}
            }
            let client=AgentClient(resources:Bundle.main.resourceURL!);try client.launch()
            let status=try await client.request(Data("{\"operation\":\"helperStatus\"}".utf8))
            if CommandLine.arguments.contains("--refresh-helper-registration") {
                let result=try JSONSerialization.jsonObject(with:status) as? [String:Any]
                guard result?["ok"] as? Bool==true else{throw NSError(domain:"KLAWOS.HelperUpdate",code:1)}
                FileHandle.standardOutput.write(status+Data([10]));exit(0)
            }
            let read=try await client.request(Data("{\"operation\":\"read\"}".utf8))
            let response=try JSONSerialization.jsonObject(with:read) as! [String:Any]
            var summary:[String:Any]=["recordingAccess":AXIsProcessTrusted(),"agent":try JSONSerialization.jsonObject(with:status),"readOK":response["ok"] ?? false]
            if let result=response["result"] as? [String:Any]{summary["identity"]=result["identity"];summary["revision"]=result["revision"]}else{summary["error"]=response["error"]}
            let output=try JSONSerialization.data(withJSONObject:summary,options:.sortedKeys);FileHandle.standardOutput.write(output+Data([10]));exit(response["ok"] as? Bool==true ? 0:1)
        }catch{FileHandle.standardError.write(Data("Agent integration check failed: \(error)\n".utf8));exit(2)}
    }
}
