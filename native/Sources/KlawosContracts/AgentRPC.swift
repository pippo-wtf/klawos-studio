import Foundation
import Darwin
import Security
import ServiceManagement
@objc public protocol AgentRPC {
    func perform(_ data:Data,reply:@escaping(Data)->Void)
}
public enum AgentPaths {
    public static var directory:URL{FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("KLAWOS Studio")}
    public static var endpoint:URL{directory.appendingPathComponent("agent.endpoint")}
    public static func executablePath(pid:pid_t)->String? {
        var path=[CChar](repeating:0,count:4096)
        guard proc_pidpath(pid,&path,UInt32(path.count))>0 else{return nil}
        return String(decoding:path.prefix{ $0 != 0 }.map{UInt8(bitPattern:$0)},as:UTF8.self)
    }
    public static func validCaller(_ connection:NSXPCConnection,expected:URL)->Bool {
        guard executablePath(pid:connection.processIdentifier)==expected.path else{return false}
        var code:SecCode?
        guard SecCodeCopyGuestWithAttributes(nil,[kSecGuestAttributePid:connection.processIdentifier] as CFDictionary,[],&code)==errSecSuccess,let code else{return false}
        return SecCodeCheckValidity(code,[],nil)==errSecSuccess
    }
}
private final class RPCReply: @unchecked Sendable {
    let lock=NSLock();var completed=false
    let continuation:CheckedContinuation<Data,any Error>;let connection:NSXPCConnection
    init(_ continuation:CheckedContinuation<Data,any Error>,_ connection:NSXPCConnection){self.continuation=continuation;self.connection=connection}
    func finish(_ result:Result<Data,any Error>){lock.lock();guard !completed else{lock.unlock();return};completed=true;lock.unlock();connection.invalidate();continuation.resume(with:result)}
}
public struct AgentClient:Sendable {
    public let resources:URL
    public init(resources:URL){self.resources=resources}
    public func launch()throws {
        let service=SMAppService.agent(plistName:"com.pippo.klawos.agent.plist")
        if service.status == .notRegistered || service.status == .notFound {try service.register()}
        guard service.status == .enabled else{throw NSError(domain:"KLAWOS.AgentRegistration",code:service.status.rawValue,userInfo:[NSLocalizedDescriptionKey:"Background helper registration status: \(service.status.rawValue). Allow KLAWOS Studio in System Settings > General > Login Items & Extensions."])}
    }
    public func request(_ data:Data)async throws->Data {
        let connection=NSXPCConnection(machServiceName:"com.pippo.klawos.agent",options:[])
        connection.remoteObjectInterface=NSXPCInterface(with:AgentRPC.self);connection.resume()
        return try await withCheckedThrowingContinuation{continuation in
            let reply=RPCReply(continuation,connection)
            connection.interruptionHandler={reply.finish(.failure(CocoaError(.xpcConnectionInterrupted)))}
            guard let remote=connection.remoteObjectProxyWithErrorHandler({error in reply.finish(.failure(error))}) as? AgentRPC else{reply.finish(.failure(CocoaError(.xpcConnectionInvalid)));return}
            remote.perform(data){value in reply.finish(value.count<=8*1024*1024 ? .success(value):.failure(CocoaError(.fileReadTooLarge)))}
            DispatchQueue.global().asyncAfter(deadline:.now()+125){reply.finish(.failure(CocoaError(.xpcConnectionInterrupted)))}
        }
    }
}
