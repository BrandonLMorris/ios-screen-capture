import XCTest

final class StopRequestTests: XCTestCase {
  private let fixture = "HAAAAGNueXPwX0I1un8AAHBvdHMQSf0CAQAAAA=="
  private let replyFixture = "GAAAAHlscHIQSf0CAQAAAAAAAAAAAAAA"

  func testRequestFixture() throws {
    let packet = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! StopRequest

    XCTAssertEqual(0x7FBA_3542_5FF0, packet.clock)
    XCTAssertEqual("EEn9AgEAAAA=", packet.correlationId)
  }

  func testResponseFixture() throws {
    let packet = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! StopRequest

    let reply = packet.reply()

    XCTAssertEqual(reply.data.base64EncodedString(), replyFixture)
  }
}
