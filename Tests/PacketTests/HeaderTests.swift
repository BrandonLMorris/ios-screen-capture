import Testing

@testable import Packet

final class HeaderTests {

  @Test func serializeSimple() throws {
    let header = Header(length: 42, type: .async)

    let serialized = header.serialized

    #expect(serialized.count == 8)
    #expect(serialized[uint32: 0] == UInt32(42))
    // asyn -> nysa
    #expect(String(data: serialized.subdata(in: 4..<8), encoding: .ascii) == "nysa")
  }

  @Test func serializeHeaderWithSubtype() throws {
    let header = Header(length: 420, type: .sync, subtype: .audioFormat)

    let serialized = header.serialized

    #expect(serialized.count == 20)
    #expect(serialized[uint32: 0] == UInt32(420))
    // sync -> cnys
    #expect(serialized[strType: 4] == "cnys")
    #expect(serialized[uint64: 8] == 0)
    // afmt -> tmfa
    #expect(serialized[strType: 16] == "tmfa")
  }

  @Test func serializeHeaderWithPayload() throws {
    let payload = UInt64(12345)
    var header = Header(length: 123, type: .sync, subtype: .audioClock)
    header.payload.uint64(at: 0, payload)

    let serialized = header.serialized

    #expect(serialized[uint64: 8] == payload)
  }

  @Test func parseHeaderWithPayload() throws {
    let payload = UInt64(12345)
    var header = Header(length: 123, type: .sync, subtype: .audioClock)
    header.payload.uint64(at: 0, payload)
    let serialized = header.serialized

    let parsed = Header(serialized)!

    #expect(parsed.payload[uint64: 0] == payload)
  }

  @Test func parseHeaderBadSubtype() throws {
    var serialized = Header(length: 123, type: .sync, subtype: .audioClock).serialized
    serialized.uint32(at: 16, UInt32(42))

    #expect(Header(serialized) == nil)
  }
}
