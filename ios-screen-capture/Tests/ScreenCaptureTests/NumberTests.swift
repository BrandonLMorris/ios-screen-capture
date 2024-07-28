import XCTest

final class NumberTests: XCTestCase {

  func testSerializeNumberWithInt32Value() throws {
    let val = UInt32(42)
    let serialized = Number(int32: val).serialize()

    XCTAssertEqual(serialized.count, 13)
    XCTAssertEqual(serialized[strType: 4], "vbmn")
    XCTAssertEqual(serialized[8], UInt8(3))
    XCTAssertEqual(serialized[uint32: 9], UInt32(42))
  }

  func testSerializeNumberWithInt64Value() throws {
    let val = UInt64(2 << 64)
    let n = Number(int64: val)

    let serialized = n.serialize()

    XCTAssertEqual(serialized.count, 17)
    XCTAssertEqual(serialized[strType: 4], "vbmn")
    XCTAssertEqual(serialized[8], UInt8(4))
    XCTAssertEqual(serialized[uint64: 9], val)
  }

  func testSerializeNumberWithFloat64Value() throws {
    let val = Float64(3.14)
    let n = Number(float64: val)

    let serialized = n.serialize()

    XCTAssertEqual(serialized.count, 17)
    XCTAssertEqual(serialized[strType: 4], "vbmn")
    XCTAssertEqual(serialized[8], UInt8(6))
    let valueDiff = abs(serialized[float64: 9] - val)
    XCTAssertLessThan(valueDiff, 1e-5)
  }

  func testParseNumberWithInt32Value() throws {
    let parsed = Number(Number(int32: 42).serialize())!

    XCTAssertEqual(parsed.int32Value, 42)
  }

  func testParseNumberWithInt64Value() throws {
    let v = UInt64(2 << 63)
    let parsed = Number(Number(int64: v).serialize())!

    XCTAssertEqual(parsed.int64Value, v)
  }

  func testParseNumberWithFloat64Value() throws {
    let e = 2.72
    let parsed = Number(Number(float64: 2.72).serialize())!

    let diff = abs(parsed.float64Value - e)
    XCTAssertLessThan(diff, 1e-5)
  }
}
