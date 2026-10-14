import Foundation
public enum ReadOnlyReport {
    public enum Failure: Error { case invalidLength, forbiddenCommand }
    public static func validate(_ data: Data) throws -> Data {
        guard !data.isEmpty && data.count <= 32 else { throw Failure.invalidLength }
        let cmd = data[0], sub = data.count > 1 ? data[1] : 0xff
        let allowed: Bool
        switch cmd {
        case 1, 0x0c, 0x0d, 0x0e, 0x11, 0x12: allowed = true
        case 2: allowed = sub == 2
        case 8: allowed = [9,10,0x80,0x81,0x82,0x83,0x40,0x41,0x42].contains(sub)
        case 0xfe:
            allowed = [0,1,2,3,5,9,10].contains(sub) || (sub == 13 && data.count > 2 && [0,1,3,5,7].contains(data[2]))
        default: allowed = false
        }
        guard allowed else { throw Failure.forbiddenCommand }
        return data + Data(repeating: 0, count: 32-data.count)
    }
}
