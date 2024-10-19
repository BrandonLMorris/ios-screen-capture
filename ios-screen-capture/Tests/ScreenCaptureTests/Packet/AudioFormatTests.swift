import Foundation
import Testing

final class AudioFormatTests {
  let fixture =
    "RAAAAGNueXOwDOJspn8AAHRtZmGAnSITAQAAAAAAAAAAcOdAbWNwbEwAAAAEAAAAAQAAAAQAAAACAAAAEAAAAAAAAAA="
  let replyFixture =
    "PgAAAHlscHKAnSITAQAAAAAAAAAqAAAAdGNpZCIAAAB2eWVrDQAAAGtydHNFcnJvcg0AAAB2Ym1uAwAAAAA="

  @Test func fixtureParsing() throws {
    let binary = Data(base64Encoded: fixture)!

    let packet = try PacketParser.parse(from: binary) as? AudioFormat
    #expect(packet != nil)
  }

  @Test func replyFixtureParsing() throws {
    let binary = Data(base64Encoded: fixture)!
    let packet = try PacketParser.parse(from: binary) as! AudioFormat

    #expect(packet.reply().data.base64EncodedString() == replyFixture)
  }
}
