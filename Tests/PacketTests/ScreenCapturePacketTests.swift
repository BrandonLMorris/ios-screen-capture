import Foundation
import Testing

@testable import Object
@testable import Packet

final class ScreenCapturePacketTests {
  // The ping packet is constant; both sending and receiving
  let ping = Data(base64Encoded: "EAAAAGduaXAAAAAAAQAAAA==")!

  @Test func parsePingHeader() throws {
    let header = Header(ping)!
    #expect(header == Header(length: 16, type: .ping))
  }

  @Test func parsePingHeaderTooShort() throws {
    // Header must be at least 8 bytes, so try one off
    let shortPayload = Data(repeating: 0xff, count: 7)
    #expect(Header(shortPayload) == nil)
  }

  @Test func parseHeaderUnknownType() throws {
    let unknownType = Data(repeating: 0xff, count: 8)
    #expect(Header(unknownType) == nil)
  }

  @Test func parsePingPacket() throws {
    #expect(throws: Never.self) {
      _ = try PacketParser.parse(from: ping) as! Ping
    }
  }

  @Test func parseErrorsEmptyPacket() throws {
    #expect(throws: PacketParsingError.self) {
      _ = try PacketParser.parse(from: Data(count: 0))
    }
  }

  @Test func testParseInvalidPing() throws {
    // Good header, but payload too short
    let badPing = ping.subdata(in: 0..<12)
    #expect(throws: PacketParsingError.self) {
      _ = try PacketParser.parse(from: badPing)
    }
  }
}

final class ScreenCaptureObjectTests {

  @Test func parsePrefix() throws {
    let serialized = Data(base64Encoded: "KAAAAGtydHM=")!
    print(serialized.base64EncodedString())
    let parsed = Prefix(serialized)

    #expect(parsed?.type == .stringKey)
    #expect(parsed?.length == 40)
  }

  @Test func serailizePrefix() throws {
    let parsed = Prefix(length: UInt32(40), type: .stringKey)

    #expect(parsed.serialize().base64EncodedString() == "KAAAAGtydHM=")
  }
}
