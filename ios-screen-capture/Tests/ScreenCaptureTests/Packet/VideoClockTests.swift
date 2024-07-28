import XCTest

@testable import ios_screen_capture

/// Tests for the video clock (cvrp) packet.
final class VideoClockTests: XCTestCase {

  func testParseFixture() throws {
    let fixture = "iQIAAGNueXMBAAAAAAAAAHBydmPQWVYTAQAAAKCNUxMBAAAAZQIAAHRjaWTHAAAAdnllayMAAABrcnRzUHJlcGFyZWRRdWV1ZUhpZ2hXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EBQAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAAxgAAAHZ5ZWsiAAAAa3J0c1ByZXBhcmVkUXVldWVMb3dXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EAwAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAA0AAAAHZ5ZWsZAAAAa3J0c0Zvcm1hdERlc2NyaXB0aW9urwAAAGNzZGYMAAAAYWlkbWVkaXYQAAAAbWlkdmYEAACECQAADAAAAGNkb2MxY3ZhfwAAAG50eGVYAAAAdnllawoAAABreGRpMQBGAAAAdGNpZD4AAAB2eWVrCgAAAGt4ZGlpACwAAAB2dGFkAWQAM//hABEnZAAzrFaARwEz5p5uBAQEBAEABCjuPLD9+PgAHwAAAHZ5ZWsKAAAAa3hkaTQADQAAAHZydHNILjI2NA=="
    let binary = Data(base64Encoded: fixture)
    let packet = try PacketParser.parse(from: binary!)
    guard let _ = packet as? VideoClock else {
      XCTFail()
      return
    }
  }
}