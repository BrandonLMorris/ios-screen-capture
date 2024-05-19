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
      XCTAssertEqual(String(data: serialized.subdata(in: idx..<(idx + 4)), encoding: .ascii)!, v)
      idx += 8
    }
  }

  func testParsingWithStringValue() throws {
    let arr = Array()
    let strValue: DictValue = .string("bar0")
    arr[52] = strValue
    let serialized = arr.serialize()

    let parsed = Array(serialized)!

    XCTAssertEqual(parsed[52]!, strValue)
  }

  func testParsingWithMultipleValues() throws {
    let arr = Array()
    let num = Number(float64: 3.14159)
    let strValue: DictValue = .string("veryveryveryverylongstring")
    arr[123] = .number(num)
    arr[456] = strValue
    let serialized = arr.serialize()

    let parsed = Array(serialized)!

    guard case let .number(n) = parsed[123]! else {
      XCTFail()
      return
    }
    XCTAssert(floatNumbersAlmostEqual(n1: n, n2: num))
    XCTAssertEqual(parsed[456]!, strValue)
  }

  func testParsingAllValueTypes() throws {
    let arr = Array()
    var d = Dictionary()
    d["foo0"] = .string("bar0")
    arr[0] = .dict(d)
    arr[1] = .data(Data([0xde, 0xad, 0xbe, 0xef]))
    arr[2] = .bool(true)
    arr[3] = .string("bingbangbong")
    arr[4] = .number(Number(int64: 12345))
    let serialized = arr.serialize()

    let parsed = Array(serialized)!
    for i in 0...4 {
      XCTAssertEqual(parsed[i], arr[i])
    }
  }

  private func floatNumbersAlmostEqual(n1: Number, n2: Number) -> Bool {
    let diff = abs(n1.float64Value - n2.float64Value)
    return diff < 1e-5
  }
}
