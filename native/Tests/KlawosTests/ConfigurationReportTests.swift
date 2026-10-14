import XCTest
@testable import KlawosContracts
final class ConfigurationReportTests: XCTestCase {
    func testConfigurationPacketsAndReadGuardRemainSeparate() throws {
        let packet=Data([5,0,0,0,0,5])
        XCTAssertEqual(try ConfigurationReport.validate(packet).count,32)
        XCTAssertThrowsError(try ReadOnlyReport.validate(packet))
        XCTAssertThrowsError(try ConfigurationReport.validate(Data([0x0a])))
        XCTAssertThrowsError(try ConfigurationReport.validate(Data([0xfe,0x0c])))
        XCTAssertThrowsError(try ConfigurationReport.validate(Data([5,6,0,0,0,5])))
    }
    func testPacketLengthsAndMacroBounds() throws {
        XCTAssertThrowsError(try ConfigurationReport.validate(Data([5,0])))
        XCTAssertThrowsError(try ConfigurationReport.validate(Data([15,0,0,29])+Data(repeating:0,count:29)))
        XCTAssertThrowsError(try ConfigurationReport.validate(Data([15,11,28,2,0,0])))
        XCTAssertEqual(try ConfigurationReport.validate(Data([15,0,0,2,0,0])).count,32)
    }
}
