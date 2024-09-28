import XCTest

@testable import ios_screen_capture

/// Tests for the video clock (cvrp) packet.
final class VideoClockTests: XCTestCase {
  let fixture =
    "iQIAAGNueXMBAAAAAAAAAHBydmPQWVYTAQAAAKCNUxMBAAAAZQIAAHRjaWTHAAAAdnllayMAAABrcnRzUHJlcGFyZWRRdWV1ZUhpZ2hXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EBQAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAAxgAAAHZ5ZWsiAAAAa3J0c1ByZXBhcmVkUXVldWVMb3dXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EAwAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAA0AAAAHZ5ZWsZAAAAa3J0c0Zvcm1hdERlc2NyaXB0aW9urwAAAGNzZGYMAAAAYWlkbWVkaXYQAAAAbWlkdmYEAACECQAADAAAAGNkb2MxY3ZhfwAAAG50eGVYAAAAdnllawoAAABreGRpMQBGAAAAdGNpZD4AAAB2eWVrCgAAAGt4ZGlpACwAAAB2dGFkAWQAM//hABEnZAAzrFaARwEz5p5uBAQEBAEABCjuPLD9+PgAHwAAAHZ5ZWsKAAAAa3hkaTQADQAAAHZydHNILjI2NA=="
  let replyFixture = "HAAAAHlscHLQWVYTAQAAAAAAAABQAtFspn8AAA=="

  func testParseFixture() throws {
    let binary = Data(base64Encoded: fixture)!
    let packet = try PacketParser.parse(from: binary)
    guard packet as? VideoClock != nil else {
      XCTFail()
      return
    }
  }

  func testReply() throws {
    let binary = Data(base64Encoded: fixture)!
    let packet = try PacketParser.parse(from: binary) as! VideoClock
    // Clock taken from the fixture
    let reply = packet.reply(withClock: 0x7FA6_6CD1_0250)
    XCTAssertEqual(replyFixture, reply.data.base64EncodedString())
  }
}
