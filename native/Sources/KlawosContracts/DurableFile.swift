import Foundation
import Darwin
public enum DurableFile {
    public static func write(_ data:Data,to destination:URL)throws {
        guard data.count<=4*1024*1024 else{throw ContractError.tooLarge}
        let directory=destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let temp=directory.appendingPathComponent(".\(UUID().uuidString).tmp")
        let fd=Darwin.open(temp.path,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0o600)
        guard fd>=0 else{throw POSIXError(.EIO)}
        let handle=FileHandle(fileDescriptor:fd,closeOnDealloc:true)
        defer{try? handle.close();try? FileManager.default.removeItem(at:temp)}
        try handle.write(contentsOf:data);try handle.synchronize();try handle.close()
        guard Darwin.rename(temp.path,destination.path)==0 else{throw POSIXError(.EIO)}
        let directoryFD=Darwin.open(directory.path,O_RDONLY);guard directoryFD>=0 else{throw POSIXError(.EIO)}
        defer{Darwin.close(directoryFD)};guard fsync(directoryFD)==0 else{throw POSIXError(.EIO)}
    }
}
