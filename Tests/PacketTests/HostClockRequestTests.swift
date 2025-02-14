import Foundation
import Testing

@testable import Packet

final class HostClockRequestTests {
  let fixture = "HAAAAGNueXNQAtFspn8AAGtvbGNwSVgTAQAAAA=="
  let replyFixture = "HAAAAHlscHJwSVgTAQAAAAAAAACAecF8pn8AAA=="

  @Test func fixtureParsing() throws {
    let fixture = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! HostClockRequest

    // Values taken from fixture
    #expect(fixture.clock == UInt(0x7FA6_6CD1_0250))
    #expect(fixture.correlationId == "cElYEwEAAAA=")
  }

  @Test func replyFixtureParsing() throws {
    let fixture = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! HostClockRequest

    // Taken from fixture
    let reply = fixture.reply(withClock: UInt(0x7FA6_7CC1_7980))

    #expect(reply.data.base64EncodedString() == replyFixture)
  }

}
