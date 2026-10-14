import Foundation
import IOKit
import IOKit.hid
import KlawosContracts

struct DeviceInfo: Codable {
    let pathToken: String
    let vendorID: Int
    let productID: Int
    let usagePage: Int
    let usage: Int
    let generation: String
    let productName: String
}
enum ProbeError: Error { case noDevice, ambiguousDevice, openFailed(Int32), sendFailed(Int32), timeout, badResponse }
final class DeviceSession {
    let device: IOHIDDevice
    let info: DeviceInfo
    let buffer: UnsafeMutablePointer<UInt8>
    var replies: [Data] = []
    init(device: IOHIDDevice, info: DeviceInfo) throws {
        self.device = device; self.info = info
        self.buffer = .allocate(capacity: 64); buffer.initialize(repeating: 0, count: 64)
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { buffer.deallocate(); throw ProbeError.openFailed(result) }
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, result, _, _, _, report, length in
            guard result == kIOReturnSuccess, let context else { return }
            let session = Unmanaged<DeviceSession>.fromOpaque(context).takeUnretainedValue()
            session.replies.append(Data(bytes: report, count: length))
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }
    deinit {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        buffer.deinitialize(count: 64); buffer.deallocate()
    }
    func exchange(_ request: Data, timeout: TimeInterval = 2) throws -> Data {
        let packet = try ReadOnlyReport.validate(request)
        replies.removeAll()
        let result = packet.withUnsafeBytes { bytes in
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, bytes.bindMemory(to: UInt8.self).baseAddress!, 32)
        }
        guard result == kIOReturnSuccess else { throw ProbeError.sendFailed(result) }
        let deadline = Date().addingTimeInterval(timeout)
        while replies.isEmpty && Date() < deadline {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, min(0.05, max(0, deadline.timeIntervalSinceNow)), true)
        }
        guard let response = replies.first else { throw ProbeError.timeout }
        guard response.count == 32 else { throw ProbeError.badResponse }
        return response
    }
}
func intProperty(_ device: IOHIDDevice, _ name: CFString) -> Int {
    (IOHIDDeviceGetProperty(device, name) as? NSNumber)?.intValue ?? -1
}
func enumerate() -> [(IOHIDDevice,DeviceInfo)] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x5241, kIOHIDProductIDKey: 0x1234, kIOHIDPrimaryUsagePageKey: 0xff60, kIOHIDPrimaryUsageKey: 0x61] as CFDictionary)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    defer {
        _ = IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }
    let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openStatus == kIOReturnSuccess else {
        fputs("HID manager open failed: \(openStatus)\n",stderr)
        return []
    }
    guard let set = IOHIDManagerCopyDevices(manager) else { fputs("HID manager set missing\n",stderr); return [] }
    let devices = (set as NSSet).allObjects.map { $0 as! IOHIDDevice }
    return devices.compactMap { device in
        let page = intProperty(device,kIOHIDPrimaryUsagePageKey as CFString)
        let usage = intProperty(device,kIOHIDPrimaryUsageKey as CFString)
        let vendor = intProperty(device,kIOHIDVendorIDKey as CFString)
        let product = intProperty(device,kIOHIDProductIDKey as CFString)
        guard vendor == 0x5241 && product == 0x1234 && page == 0xff60 && usage == 0x61 else { return nil }
        var registry: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &registry) == kIOReturnSuccess else { return nil }
        let token = String(registry)
        let info = DeviceInfo(pathToken: token,vendorID:0x5241,productID:0x1234,usagePage:page,usage:usage,
            generation:token,productName:(IOHIDDeviceGetProperty(device,kIOHIDProductKey as CFString) as? String) ?? "KLAWOS")
        return (device,info)
    }.sorted { $0.1.pathToken < $1.1.pathToken }
}
struct ExchangeRequest: Decodable { let requestID: String; let report: String }
struct ExchangeReply: Encodable { let requestID: String; let report: String?; let error: String? }
func emit<T: Encodable>(_ value: T) throws {
    let data = try JSONEncoder().encode(value)
    FileHandle.standardOutput.write(data + Data([10]))
}
func decodeHex(_ string: String) throws -> Data {
    guard string.count % 2 == 0, string.count <= 64 else { throw ProbeError.badResponse }
    var out = Data(); var index = string.startIndex
    while index < string.endIndex {
        let next = string.index(index,offsetBy:2)
        guard let value = UInt8(string[index..<next],radix:16) else { throw ProbeError.badResponse }
        out.append(value); index = next
    }
    return out
}
let arguments = CommandLine.arguments
let found = enumerate()
if arguments.count == 2 && arguments[1] == "--list" { try emit(found.map(\.1)); exit(0) }
guard arguments.count == 3 && arguments[1] == "--exchange" else { fputs("usage: KlawosProbe --list | --exchange PATH_TOKEN\n",stderr); exit(2) }
let matches = found.filter { $0.1.pathToken == arguments[2] }
guard matches.count == 1 else { fputs("Physical device selection required\n",stderr); exit(3) }
let session = try DeviceSession(device: matches[0].0,info: matches[0].1)
try emit(session.info)
while let line = readLine() {
    do {
        let request = try JSONDecoder().decode(ExchangeRequest.self,from:Data(line.utf8))
        guard !request.requestID.isEmpty && request.requestID.count <= 128 else { throw ProbeError.badResponse }
        let result = try session.exchange(decodeHex(request.report))
        try emit(ExchangeReply(requestID:request.requestID,report:result.map { String(format:"%02x",$0) }.joined(),error:nil))
    } catch {
        try emit(ExchangeReply(requestID:"",report:nil,error:String(describing:error)))
        exit(4) // A failed or timed-out report invalidates response correlation.
    }
}
