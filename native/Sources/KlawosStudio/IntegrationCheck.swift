import Foundation
import ApplicationServices
import ServiceManagement
import KlawosContracts
@MainActor func integrationCheck() {
    Task {
        do{
            if CommandLine.arguments.contains("--reset-agent-registration"){try await SMAppService.agent(plistName:"com.pippo.klawos.agent.plist").unregister()}
            let client=AgentClient(resources:Bundle.main.resourceURL!);try client.launch()
            let status=try await client.request(Data("{\"operation\":\"helperStatus\"}".utf8))
            let read=try await client.request(Data("{\"operation\":\"read\"}".utf8))
            let response=try JSONSerialization.jsonObject(with:read) as! [String:Any]
            var summary:[String:Any]=["recordingAccess":AXIsProcessTrusted(),"agent":try JSONSerialization.jsonObject(with:status),"readOK":response["ok"] ?? false]
            if let result=response["result"] as? [String:Any]{summary["identity"]=result["identity"];summary["revision"]=result["revision"]}else{summary["error"]=response["error"]}
            let output=try JSONSerialization.data(withJSONObject:summary,options:.sortedKeys);FileHandle.standardOutput.write(output+Data([10]));exit(response["ok"] as? Bool==true ? 0:1)
        }catch{FileHandle.standardError.write(Data("Agent integration check failed: \(error)\n".utf8));exit(2)}
    }
}
