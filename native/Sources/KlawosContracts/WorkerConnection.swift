import Foundation
public struct Worker: Sendable {
    public let resources: URL
    public init(resources:URL){self.resources=resources}
    public func request(_ data: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos:.userInitiated).async {
                do {
                    let process=Process();let input=Pipe();let output=Pipe()
                    process.executableURL=resources.appendingPathComponent("python/bin/python3.12")
                    let store=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("KLAWOS Studio")
                    process.arguments=["-m","klawos_device.app_service","--probe",resources.appendingPathComponent("KlawosProbe").path,"--store",store.path]
                    process.environment=["PYTHONPATH":resources.appendingPathComponent("service").path,"PYTHONDONTWRITEBYTECODE":"1","HOME":NSHomeDirectory(),"PATH":"/usr/bin:/bin"]
                    process.standardInput=input;process.standardOutput=output;process.standardError=FileHandle.nullDevice
                    try process.run()
                    let timeout=DispatchWorkItem { if process.isRunning { process.terminate() } }
                    DispatchQueue.global().asyncAfter(deadline:.now()+120,execute:timeout)
                    try input.fileHandleForWriting.write(contentsOf:data);try input.fileHandleForWriting.close()
                    let result=try output.fileHandleForReading.readToEnd() ?? Data()
                    process.waitUntilExit();timeout.cancel()
                    guard process.terminationStatus==0 && result.count<=8*1024*1024 else { throw NSError(domain:"KLAWOS",code:1) }
                    continuation.resume(returning:result)
                } catch { continuation.resume(throwing:error) }
            }
        }
    }
}
