import Foundation
import CryptoKit
import CoreGraphics
import Darwin
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
    var connected = true
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
        IOHIDDeviceRegisterRemovalCallback(device, { context, _, _ in
            guard let context else { return }
            Unmanaged<DeviceSession>.fromOpaque(context).takeUnretainedValue().connected = false
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }
    deinit {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        buffer.deinitialize(count: 64); buffer.deallocate()
    }
    func exchange(_ request: Data, timeout: TimeInterval = 2) throws -> Data {
        return try exchangeValidated(ReadOnlyReport.validate(request), timeout: timeout)
    }
    func exchangeSecurity(_ request: Data) throws -> Data {
        try exchangeValidated(SecurityReport.validate(request), timeout: 2)
    }
    func exchangeConfiguration(_ request: Data) throws -> Data {
        try exchangeValidated(ConfigurationReport.validate(request), timeout: 2)
    }
    func exchangeKeyTest(_ request: Data) throws -> Data {
        try exchangeValidated(NarrowKeyTestReport.validate(request), timeout: 2)
    }
    func exchangeLightingRecovery(_ request: Data) throws -> Data {
        try exchangeValidated(NarrowLightingRecoveryReport.validate(request), timeout: 2)
    }
    private func exchangeValidated(_ packet: Data, timeout: TimeInterval) throws -> Data {
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
func runKeyRoundTrip(device: IOHIDDevice, info: DeviceInfo, backupPath: String, lightingRecovery: Bool = false, inputProof: Bool = false) throws {
    let backupURL = URL(fileURLWithPath: backupPath).resolvingSymlinksInPath()
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard backupURL.deletingLastPathComponent() == project.appendingPathComponent("configs").resolvingSymlinksInPath() else { throw ProbeError.badResponse }
    let backupData = try Data(contentsOf: backupURL)
    guard backupData.count <= 4 * 1024 * 1024 else { throw ProbeError.badResponse }
    let backup = try JSONDecoder().decode(Snapshot.self, from: backupData)
    guard backup.identity.uid == "6994672159869375106", backup.identity.vialProtocol == 5,
          backup.unreadableFields.isEmpty,
          case .array(let layers) = backup.hardware["layout"], layers.count == 6,
          case .array(let rows) = layers[0], rows.count == 4,
          case .array(let keys) = rows[0], keys.count == 4, keys[0] == .string("KC_A") else { throw ProbeError.badResponse }
    let session = try DeviceSession(device: device, info: info)
    let identity = try session.exchange(Data([0xfe,0]))
    let protocolVersion = identity.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
    let uid = identity[4..<12].enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << ($1.offset * 8) }
    guard protocolVersion == 5, String(uid) == backup.identity.uid else { throw ProbeError.badResponse }
    let journalURL = backupURL.appendingPathExtension(lightingRecovery ? "lighting-recovery.jsonl" : inputProof ? "input-proof.jsonl" : "roundtrip.jsonl")
    let descriptor = Darwin.open(journalURL.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw POSIXError(.EIO) }
    let journal = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer { try? journal.close() }
    let checksum = SHA256.hash(data: backupData).map { String(format: "%02x", $0) }.joined()
    func record(_ state: String) throws {
        let value: [String: String] = ["state": state, "uid": String(uid), "pathToken": info.pathToken,
            "backup": backupURL.lastPathComponent, "backupSHA256": checksum,
            "field": lightingRecovery ? "lighting.vialrgb.hsv.0" : "hardware.layout.0.0.0", "original": lightingRecovery ? "216" : "KC_A", "temporary": lightingRecovery ? "208" : "KC_F13"]
        try journal.write(contentsOf: JSONEncoder().encode(value) + Data([10])); try journal.synchronize()
    }
    try record("prepared")
    let directoryFD = Darwin.open(journalURL.deletingLastPathComponent().path, O_RDONLY)
    guard directoryFD >= 0 else { throw POSIXError(.EIO) }
    let syncResult = fsync(directoryFD); Darwin.close(directoryFD)
    guard syncResult == 0 else { throw POSIXError(.EIO) }
    if lightingRecovery {
        guard case .object(let rgb) = backup.lighting["vialrgb"], rgb["mode"] == .integer(3),
              rgb["speed"] == .integer(63), rgb["hsv"] == .array([.integer(216),.integer(93),.integer(71)]) else { throw ProbeError.badResponse }
        func lightingPayload() throws -> Data {
            let reply = try session.exchange(Data([8,0x41]))
            guard reply.prefix(2) == Data([8,0x41]) else { throw ProbeError.badResponse }
            return Data(reply[2..<8])
        }
        let original = Data([3,0,63,216,93,71]); let observed = try lightingPayload()
        guard observed == Data([3,0,63,208,93,71]) || observed == original else { throw ProbeError.badResponse }
        if observed != original {
            try record("lighting-restore-intent")
            do { _ = try session.exchangeLightingRecovery(Data([7,0x41]) + original) }
            catch { /* Readback decides outcome; no automatic retry. */ }
        }
        guard try lightingPayload() == original else {
            try record("lighting-recovery-required"); throw ProbeError.badResponse
        }
        try record("lighting-restored-verified")
        try emit(["result": "lighting-restored", "journal": journalURL.path]); return
    }
    let capture = inputProof ? InputTapController(deviceGeneration: info.generation, connected: { session.connected }) : nil
    if let capture { try capture.start() }
    defer { capture?.stop() }
    let result = try KeyRoundTrip.run(expected: 4, temporary: 104, read: {
        let query = Data([0x12,0,0,2]); let response = try session.exchange(query)
        guard response.prefix(4) == query else { throw ProbeError.badResponse }
        return UInt16(response[4]) << 8 | UInt16(response[5])
    }, write: { code in
        let packet = Data([5,0,0,0,UInt8(code >> 8),UInt8(code & 255)])
        let response = try session.exchangeKeyTest(packet)
        guard response.prefix(6) == packet else { throw ProbeError.badResponse }
    }, journal: record, duringTemporary: {
        guard let capture else { return }
        try? emit(["phase": "input-test-ready", "durationSeconds": "30", "instruction": "Press and release the top-left Work key three times; keep the knob unchanged."])
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline && capture.isActive {
            CFRunLoopRunInMode(.defaultMode, 0.05, false)
            capture.checkConnection()
        }
        capture.stop(reason: "test-window-ended")
        try? emit(["presses": capture.pressCount, "releases": capture.releaseCount, "cleanup": capture.cleanupCount])
    })
    try record(result.rawValue)
    try emit(["result": result.rawValue, "journal": journalURL.path, "uid": String(uid)])
    if result != .restored { exit(5) }
}

let arguments = CommandLine.arguments
if arguments.count == 2 && arguments[1] == "--input-preflight" {
    try emit(InputTapController.permissions); exit(0)
}
if arguments.count == 2 && arguments[1] == "--request-input-permission" {
    try emit(["inputMonitoring": CGRequestListenEventAccess()]); exit(0)
}
if arguments.count == 4 && arguments[1] == "--key-input-proof" && !InputTapController.permissions.values.allSatisfy({ $0 }) {
    try emit(["error": "input-permission-required", "permissions": InputTapController.permissions.description]); exit(7)
}
let found = enumerate()
if arguments.count == 2 && arguments[1] == "--list" { try emit(found.map(\.1)); exit(0) }
if arguments.count == 4 && ["--key-roundtrip", "--restore-test-lighting", "--key-input-proof"].contains(arguments[1]) {
    let selected = found.filter { $0.1.pathToken == arguments[2] }
    guard selected.count == 1 else { fputs("Physical device selection required\n", stderr); exit(3) }
    do { try runKeyRoundTrip(device: selected[0].0, info: selected[0].1, backupPath: arguments[3], lightingRecovery: arguments[1] == "--restore-test-lighting", inputProof: arguments[1] == "--key-input-proof"); exit(0) }
    catch { fputs("Key round-trip stopped; inspect backup and journal: \(error)\n", stderr); exit(6) }
}
guard arguments.count == 3 && ["--exchange", "--configure", "--security"].contains(arguments[1]) else { fputs("usage: KlawosProbe --list | --exchange PATH_TOKEN\n",stderr); exit(2) }
let matches = found.filter { $0.1.pathToken == arguments[2] }
guard matches.count == 1 else { fputs("Physical device selection required\n",stderr); exit(3) }
let session = try DeviceSession(device: matches[0].0,info: matches[0].1)
try emit(session.info)
while let line = readLine() {
    do {
        let request = try JSONDecoder().decode(ExchangeRequest.self,from:Data(line.utf8))
        guard !request.requestID.isEmpty && request.requestID.count <= 128 else { throw ProbeError.badResponse }
        let packet = try decodeHex(request.report)
        let result: Data
        if arguments[1] == "--configure" { result = try session.exchangeConfiguration(packet) }
        else if arguments[1] == "--security" { result = try session.exchangeSecurity(packet) }
        else { result = try session.exchange(packet) }
        try emit(ExchangeReply(requestID:request.requestID,report:result.map { String(format:"%02x",$0) }.joined(),error:nil))
    } catch {
        try emit(ExchangeReply(requestID:"",report:nil,error:String(describing:error)))
        exit(4) // A failed or timed-out report invalidates response correlation.
    }
}
