import XCTest

final class HeaderTests: XCTestCase {

  func testSerializeSimple() throws {
    let header = Header(length: 42, type: .async)

    let serialized = header.serialized

    XCTAssertEqual(serialized.count, 8)
    XCTAssertEqual(serialized[uint32: 0], UInt32(42))
    // asyn -> nysa
    XCTAssertEqual(String(data: serialized.subdata(in: 4..<8), encoding: .ascii), "nysa")
  }

  func testSerializeHeaderWithSubtype() throws {
    let header = Header(length: 420, type: .sync, subtype: .audioFormat)

    let serialized = header.serialized

    XCTAssertEqual(serialized.count, 20)
    XCTAssertEqual(serialized[uint32: 0], UInt32(420))
    // sync -> cnys
    XCTAssertEqual(serialized[strType: 4], "cnys")
    XCTAssertEqual(serialized[uint64: 8], 0)
    // afmt -> tmfa
    XCTAssertEqual(serialized[strType: 16], "tmfa")
  }

  func testSerializeHeaderWithPayload() throws {
    let payload = UInt64(12345)
    var header = Header(length: 123, type: .sync, subtype: .audioClock)
    header.payload.uint64(at: 0, payload)

    let serialized = header.serialized

    XCTAssertEqual(serialized[uint64: 8], payload)
  }

  func testParseHeaderWithPayload() throws {
    let payload = UInt64(12345)
    var header = Header(length: 123, type: .sync, subtype: .audioClock)
    header.payload.uint64(at: 0, payload)
    let serialized = header.serialized

    let parsed = Header(serialized)!

    XCTAssertEqual(parsed.payload[uint64: 0], payload)
  }

  func testParseHeaderBadSubtype() throws {
    var serialized = Header(length: 123, type: .sync, subtype: .audioClock).serialized
    serialized.uint32(at: 16, UInt32(42))

    XCTAssertNil(Header(serialized))
  }
}
