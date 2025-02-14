import Foundation
import Testing

@testable import Packet

/// Tests for the video clock (cvrp) packet.
final class VideoClockTests {
  let fixture =
    "iQIAAGNueXMBAAAAAAAAAHBydmPQWVYTAQAAAKCNUxMBAAAAZQIAAHRjaWTHAAAAdnllayMAAABrcnRzUHJlcGFyZWRRdWV1ZUhpZ2hXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EBQAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAAxgAAAHZ5ZWsiAAAAa3J0c1ByZXBhcmVkUXVldWVMb3dXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EAwAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAA0AAAAHZ5ZWsZAAAAa3J0c0Zvcm1hdERlc2NyaXB0aW9urwAAAGNzZGYMAAAAYWlkbWVkaXYQAAAAbWlkdmYEAACECQAADAAAAGNkb2MxY3ZhfwAAAG50eGVYAAAAdnllawoAAABreGRpMQBGAAAAdGNpZD4AAAB2eWVrCgAAAGt4ZGlpACwAAAB2dGFkAWQAM//hABEnZAAzrFaARwEz5p5uBAQEBAEABCjuPLD9+PgAHwAAAHZ5ZWsKAAAAa3hkaTQADQAAAHZydHNILjI2NA=="
  let replyFixture = "HAAAAHlscHLQWVYTAQAAAAAAAABQAtFspn8AAA=="
  lazy var binary = Data(base64Encoded: fixture)!

  @Test func parseFixture() throws {
    _ = try #require(PacketParser.parse(from: binary) as? VideoClock)
  }

  @Test func parseReplyFixture() throws {
    let packet = try PacketParser.parse(from: binary) as! VideoClock
    // Clock taken from the fixture
    let reply = packet.reply(withClock: 0x7FA6_6CD1_0250)
    #expect(replyFixture == reply.data.base64EncodedString())
  }

  @Test func parseFailsIfDataTooShort() throws {
    let tooShort = binary.subdata(in: 0..<8)

    #expect(VideoClock(header: Header(binary)!, data: tooShort) == nil)
  }

  @Test func videoClockDescription() throws {
    let clock = try #require(VideoClock(header: Header(binary)!, data: binary)!)

    #expect(clock.description.lowercased().contains("cvrp"))
    #expect(clock.description.lowercased().contains("video"))
  }
}
