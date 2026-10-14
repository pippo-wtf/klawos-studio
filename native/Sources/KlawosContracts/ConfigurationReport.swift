import Foundation
/// Workbook KLAWOS protocol-5 configuration boundary. Destructive reset/bootloader commands are excluded.
public enum ConfigurationReport {
    public static func validate(_ data: Data) throws -> Data {
        if let read = try? ReadOnlyReport.validate(data) { return read }
        let p=Array(data)
        guard !p.isEmpty && p.count<=32 else { throw ReadOnlyReport.Failure.invalidLength }
        var allowed=false
        switch p[0] {
        case 5: allowed=p.count==6 && p[1]<6 && p[2]<4 && p[3]<4
        case 3: allowed=p.count==6 && p[1]==2
        case 7: allowed=p.count==8 && p[1]==0x41
        case 9: allowed=p.count==1
        case 15:
            allowed=p.count>=4 && p[3]>0 && p[3]<=28 && p.count==4+Int(p[3]) && Int(p[1])*256+Int(p[2])+Int(p[3])<=2845
        case 254:
            if p.count>=2 {
                switch p[1] {
                case 4: allowed=p.count==7 && p[2]<6 && p[3]==0 && p[4]<2
                case 11: allowed=p.count>=5 && p.count<=8 && p[2]>=1 && p[2]<=21 && p[3]==0
                case 13:
                    allowed=p.count==14 && [2,4,6].contains(p[2]) && p[3]<32
                default: break
                }
            }
        default: break
        }
        guard allowed else { throw ReadOnlyReport.Failure.forbiddenCommand }
        return data+Data(repeating:0,count:32-data.count)
    }
}
public enum SecurityReport {
    public static func validate(_ data:Data)throws->Data {
        if let read=try? ReadOnlyReport.validate(data){return read}
        guard [Data([254,6]),Data([254,7]),Data([254,8]),Data([2,3])].contains(data) else {throw ReadOnlyReport.Failure.forbiddenCommand}
        return data+Data(repeating:0,count:32-data.count)
    }
}
