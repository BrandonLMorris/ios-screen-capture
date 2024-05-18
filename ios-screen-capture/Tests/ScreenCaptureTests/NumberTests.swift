import XCTest

final class NumberTests: XCTestCase {

  func testSerializeNumberWithInt32Value() throws {
    let val = UInt32(42)
    let serialized = Number(int32: val).serialize()

    XCTAssertEqual(serialized.count, 12)
    XCTAssertEqual(serialized[strType: 0], "vbmn")
    XCTAssertEqual(serialized[uint32: 4], UInt32(3))
    XCTAssertEqual(serialized[uint32: 8], UInt32(42))
  }

  func testSerializeNumberWithInt64Value() throws {
    let val = UInt64(2 << 64)
    let n = Number(int64: val)

    let serialized = n.serialize()

    XCTAssertEqual(serialized.count, 16)
    XCTAssertEqual(serialized[strType: 0], "vbmn")
    XCTAssertEqual(serialized[uint32: 4], UInt32(4))
    XCTAssertEqual(serialized[uint64: 8], val)
  }

  func testSerializeNumberWithFloat64Value() throws {
    let val = Float64(3.14)
    let n = Number(float64: val)

    let serialized = n.serialize()

    XCTAssertEqual(serialized.count, 16)
    XCTAssertEqual(serialized[strType: 0], "vbmn")
    XCTAssertEqual(serialized[uint32: 4], UInt32(6))
    let valueDiff = abs(serialized[float64: 8] - val)
    XCTAssertLessThan(valueDiff, 1e-5)
  }
}
