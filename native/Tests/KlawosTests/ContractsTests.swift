import Foundation
import XCTest
@testable import KlawosContracts

final class ContractsTests: XCTestCase {
    private func request(operation: String = "status", revision: String? = nil) throws -> Data {
        var value: [String: Any] = ["requestID": "request-1", "deviceGeneration": "device-1", "operation": operation, "payload": [:]]
        if let revision { value["draftRevision"] = revision }
        return try JSONSerialization.data(withJSONObject: value)
    }

    func testAcceptsCorrelatedStatusRequest() throws {
        let decoded = try? WireCodec.decodeRequest(request(), knownRevisions: [])
        XCTAssertNotNil(decoded, "Valid status requests must reach the agent")
        XCTAssertEqual(decoded?.requestID, "request-1")
    }

    func testRejectsUnknownOperationBeforeDispatch() throws {
        XCTAssertThrowsError(try WireCodec.decodeRequest(request(operation: "shell"), knownRevisions: []))
    }

    func testRejectsPatchWithoutValidRevision() throws {
        XCTAssertThrowsError(try WireCodec.decodeRequest(request(operation: "patch"), knownRevisions: ["r1"]))
        XCTAssertThrowsError(try WireCodec.decodeRequest(request(operation: "patch", revision: "expired"), knownRevisions: ["r1"]))
        XCTAssertNoThrow(try WireCodec.decodeRequest(request(operation: "patch", revision: "r1"), knownRevisions: ["r1"]))
    }

    func testRejectsOversizeMessage() {
        XCTAssertThrowsError(try WireCodec.decodeRequest(Data(repeating: 32, count: 4 * 1024 * 1024 + 1), knownRevisions: []))
    }

    func testDoesNotRoundUidAtBridgeBoundary() throws {
        let identity = DeviceIdentity(uid: "6994672159869375106", viaProtocol: 9, vialProtocol: 5, definitionHash: "fixture")
        let data = try JSONEncoder().encode(identity)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["uid"] as? String, "6994672159869375106")
        XCTAssertEqual(try JSONDecoder().decode(DeviceIdentity.self, from: data).uid, "6994672159869375106")
    }

    func testRejectsAmbiguousDuplicateKeys() {
        let data = Data(#"{"requestID":"a","requestID":"b","operation":"status","deviceGeneration":"d","payload":{}}"#.utf8)
        XCTAssertThrowsError(try WireCodec.decodeRequest(data, knownRevisions: []))
    }
}
