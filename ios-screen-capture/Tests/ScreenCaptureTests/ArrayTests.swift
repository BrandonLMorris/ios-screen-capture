import XCTest

final class ArrayTests: XCTestCase {

  func testReturnsIndexValue() throws {
    let v: DictValue = .string("big summer blowout")
    let arr = Array()
    arr[555] = v

    XCTAssertEqual(arr[555], v)
  }

  func testIndexAbsentReturnsNil() throws {
    XCTAssertNil(Array()[42])
  }

  func testSerializeSimple() throws {
    let arr = Array()
    arr[42] = .string("foo")

    let serialized = arr.serialize()
    
    print(serialized.base64EncodedString())
    
    XCTAssertEqual(serialized[strType: 4], "tcid")
    XCTAssertEqual(serialized[strType: 12], "vyek")
    XCTAssertEqual(serialized[strType: 20], "kxdi")
    XCTAssertEqual(serialized[uint32: 24], UInt32(42))
    // 28 + 4b length = 32
    XCTAssertEqual(serialized[strType: 32], "vrts")
    XCTAssertEqual(String(data: serialized.subdata(in: 36..<39), encoding: .ascii)!, "foo")
  }

  func testSerializeMultipleValues() throws {
    let arr = Array()
    arr[12345] = .string("abcd")
    arr[45678] = .string("efgh")

    let serialized = arr.serialize()

    var idx = 4
    XCTAssertEqual(serialized[strType: idx], "tcid")
    idx += 8
    // We serialize in sorted key order, so its safe (for testing) to assume
    // the serialized order.
    for (k, v) in [(UInt32(12345), "abcd"), (UInt32(45678), "efgh")] {
      XCTAssertEqual(serialized[strType: idx], "vyek")
      idx += 8
      XCTAssertEqual(serialized[strType: idx], "kxdi")
      idx += 4
      XCTAssertEqual(serialized[uint32: idx], k)
      idx += 8
      XCTAssertEqual(serialized[strType: idx], "vrts")
      idx += 4
      XCTAssertEqual(String(data: serialized.subdata(in: idx..<(idx+4)), encoding: .ascii)!, v)
      idx += 8
    }
  }
}
