import XCTest

final class HostClockRequestTests: XCTestCase {
  let fixture = "HAAAAGNueXNQAtFspn8AAGtvbGNwSVgTAQAAAA=="
  let replyFixture = "HAAAAHlscHJwSVgTAQAAAAAAAACAecF8pn8AAA=="

  func testFixture() throws {
    let fixture = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! HostClockRequest

    // Values taken from fixture
    XCTAssertEqual(fixture.clock, UInt(0x7FA66CD10250))
    XCTAssertEqual(fixture.correlationId, "cElYEwEAAAA=")
  }

  func testReplyFixture() throws {
    let fixture = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! HostClockRequest

    // Taken from fixture
    let reply = fixture.reply(withClock:UInt(0x7FA67CC17980))

    XCTAssertEqual(reply.data.base64EncodedString(), replyFixture)
  }

}
