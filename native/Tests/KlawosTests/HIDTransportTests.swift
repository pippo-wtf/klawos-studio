import Foundation
import XCTest
@testable import KlawosContracts
final class HIDTransportTests: XCTestCase {
    func testPadsExactly32BytesWithoutReportIDPrefix() throws {
        XCTAssertEqual(try ReadOnlyReport.validate(Data([1])).count,32)
        XCTAssertEqual(try ReadOnlyReport.validate(Data([1])).first,1)
        XCTAssertThrowsError(try ReadOnlyReport.validate(Data(repeating:1,count:33)))
    }
    func testReadOnlyGuardRejectsMutationsAndUnknownPackets() {
        for packet: [UInt8] in [[5],[3],[7],[9],[15],[0xfe,4],[0xfe,6],[0xfe,7],[0xfe,8],[0xfe,11],[0xfe,12],[0xfe,13,2],[0xfe,13,4],[]] {
            XCTAssertThrowsError(try ReadOnlyReport.validate(Data(packet)))
        }
    }
    func testAcceptsOnlySupportedReads() {
        for packet: [UInt8] in [[1],[0x11],[0x0c],[0x0d],[0x0e,0,0,28],[0x12,0,0,28],[8,0x40],[0xfe,0],[0xfe,1],[0xfe,2],[0xfe,3],[0xfe,9],[0xfe,10],[0xfe,13,0],[0xfe,13,1]] {
            XCTAssertNoThrow(try ReadOnlyReport.validate(Data(packet)))
        }
    }
}
