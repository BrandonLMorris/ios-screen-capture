import XCTest

final class HostClockRequestTests: XCTestCase {
  let fixture = "HAAAAGNueXNQAtFspn8AAGtvbGNwSVgTAQAAAA=="
  let replyFixture = "HAAAAHlscHJwSVgTAQAAAAAAAACAecF8pn8AAA=="

  func testFixture() throws {
    let fixture = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! HostClockRequest

    // Values taken from fixture
    XCTAssertEqual(fixture.clock, UInt(0x7FA6_6CD1_0250))
    XCTAssertEqual(fixture.correlationId, "cElYEwEAAAA=")
  }

  func testReplyFixture() throws {
    let fixture = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! HostClockRequest

    // Taken from fixture
    let reply = fixture.reply(withClock: UInt(0x7FA6_7CC1_7980))

    XCTAssertEqual(reply.data.base64EncodedString(), replyFixture)
  }

}
