import Foundation
import Testing

@testable import Object
@testable import Packet

final class TimeRequestTests {
  let fixture = "HAAAAGNueXOAecF8pn8AAGVtaXRQPSITAQAAAA=="
  let replyFixture = "LAAAAHlscHKAecF8pn8AAAAAAADh4ULEYroAAADKmjsBAAAAAAAAAAAAAAA="

  @Test func fixtureParsing() throws {
    let timeRequest = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! TimeRequest

    // Taken from fixture
    #expect(timeRequest.correlationId == "gHnBfKZ/AAA=")
    #expect(timeRequest.clock == CFTypeID(0x1_1322_3d50))
  }

  @Test func replyFixtureParsing() throws {
    let timeRequest = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! TimeRequest
    let replyTime = Time(Data(base64Encoded: "4eFCxGK6AAAAypo7AQAAAAAAAAAAAAAA")!)!

    let reply = timeRequest.reply(withTime: replyTime)

    #expect(reply.data.base64EncodedString() == replyFixture)
  }
}
