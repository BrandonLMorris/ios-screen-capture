import XCTest

final class AudioFormatTests: XCTestCase {
  let fixture =
    "RAAAAGNueXOwDOJspn8AAHRtZmGAnSITAQAAAAAAAAAAcOdAbWNwbEwAAAAEAAAAAQAAAAQAAAACAAAAEAAAAAAAAAA="
  let replyFixture =
    "PgAAAHlscHKAnSITAQAAAAAAAAAqAAAAdGNpZCIAAAB2eWVrDQAAAGtydHNFcnJvcg0AAAB2Ym1uAwAAAAA="

  func testWithFixture() throws {
    let binary = Data(base64Encoded: fixture)!

    let packet = try PacketParser.parse(from: binary) as? AudioFormat
    guard packet != nil else {
      XCTFail("Failed to parse audio format packet from fixture")
      return
    }
  }

  func testWithReplyFixture() throws {
    let binary = Data(base64Encoded: fixture)!
    let packet = try PacketParser.parse(from: binary) as! AudioFormat

    XCTAssertEqual(packet.reply().data.base64EncodedString(), replyFixture)
  }
}
