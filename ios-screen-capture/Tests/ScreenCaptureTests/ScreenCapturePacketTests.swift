import XCTest

@testable import ios_screen_capture

final class ScreenCapturePacketTests: XCTestCase {
  // The ping packet is constant; both sending and receiving
  let ping = Data(base64Encoded: "EAAAAGduaXAAAAAAAQAAAA==")!

  func testParsePingHeader() throws {
    let header = Header(ping)!
    XCTAssertEqual(header, Header(length: 16, type: .ping))
  }

  func testParsePingHeaderTooShort() throws {
    // Header must be at least 8 bytes, so try one off
    let shortPayload = Data(repeating: 0xff, count: 7)
    XCTAssertNil(Header(shortPayload))
  }

  func testParseHeaderUnknownType() throws {
    let unknownType = Data(repeating: 0xff, count: 8)
    XCTAssertNil(Header(unknownType))
  }

  func testParsePingPacket() throws {
    XCTAssertNoThrow(
      try { [self] in
        let parsed: ScreenCapturePacket = try PacketParser.parse(from: ping)
        _ = parsed as! Ping
      }())
  }

  func testParseErrorsEmptyPacket() throws {
    XCTAssertThrowsError(
      try {
        _ = try PacketParser.parse(from: Data(count: 0))
      }())
  }

  func testParseInvalidPing() throws {
    // Good header, but payload too short
    let badPing = ping.subdata(in: 0..<12)
    XCTAssertThrowsError(
      try {
        _ = try PacketParser.parse(from: badPing)
      }())
  }
}

final class ScreenCaptureObjectTests: XCTestCase {

  func testParsePrefix() throws {
    let serialized = Data(base64Encoded: "KAAAAGtydHM=")!
    print(serialized.base64EncodedString())
    let parsed = Prefix(serialized)

    XCTAssertEqual(parsed?.type, .stringKey)
    XCTAssertEqual(parsed?.length, 40)
  }

  func testSerailizePrefix() throws {
    let parsed = Prefix(length: UInt32(40), type: .stringKey)

    XCTAssertEqual(parsed.serialize().base64EncodedString(), "KAAAAGtydHM=")
  }
}
