import XCTest

final class DictionaryTests: XCTestCase {

  func testSerializeDictWithStringValue() throws {
    var dict = Dictionary()
    dict["foo"] = .string("bar")

    let serialized = dict.serialize()

    XCTAssertEqual(serialized[strType: 4], "tcid")
    XCTAssertEqual(serialized[strType: 12], "vyek")
    XCTAssertEqual(serialized[strType: 20], "krts")
    // Note: The actual values aren't endian-ed
    XCTAssertEqual(String(data: serialized.subdata(in: 24..<27), encoding: .ascii)!, "foo")
    // 27 + 4b length = 31
    XCTAssertEqual(serialized[strType: 31], "vrts")
    XCTAssertEqual(String(data: serialized.subdata(in: 35..<38), encoding: .ascii)!, "bar")
  }

  func testSerializeDictWithBoolValues() throws {
    var dict = Dictionary()
    dict["t"] = .bool(true)
    dict["f"] = .bool(false)

    let serialized = dict.serialize()

    // First 20 bytes are prefixes tested elsewhere
    var idx = 20
    // There are two elements, but since we're iterating over the
    // underlying dictionary we can't assume order.
    for _ in 0..<2 {
      XCTAssertEqual(serialized[strType: idx], "krts")
      idx += 4
      if serialized[idx] == Character("t").asciiValue! {
        idx += 5
        XCTAssertEqual(serialized[strType: idx], "vlub")
        idx += 4
        XCTAssertEqual(serialized[idx], UInt8(1))
      } else if serialized[idx] == Character("f").asciiValue! {
        idx += 5
        XCTAssertEqual(serialized[strType: idx], "vlub")
        idx += 4
        XCTAssertEqual(serialized[idx], UInt8(0))
      } else {
        XCTFail()
      }
      idx += 13
    }
  }

  func testSerializeDictWithDictValue() throws {
    var nested = Dictionary()
    nested["foo0"] = .string("bar0")
    var dict = Dictionary()
    dict["key1"] = .dict(nested)

    let serialized = dict.serialize()

    // First 20 bytes are prefixes tested elsewhere
    var idx = 20
    XCTAssertEqual(serialized[strType: idx], "krts")
    idx += 4
    XCTAssertEqual(serialized[strType: idx], "key1")
    idx += 8
    XCTAssertEqual(serialized[strType: idx], "tcid")  // value type
    idx += 8
    XCTAssertEqual(serialized[strType: idx], "tcid")  // prefix of dict value
    idx += 8
    XCTAssertEqual(serialized[strType: idx], "vyek")  // prefix of dict value
    idx += 8
    XCTAssertEqual(serialized[strType: idx], "krts")
    idx += 4
    XCTAssertEqual(serialized[strType: idx], "foo0")
    idx += 8
    XCTAssertEqual(serialized[strType: idx], "vrts")
    idx += 4
    XCTAssertEqual(serialized[strType: idx], "bar0")
  }

  func testSerializeDictWithNumberValue() throws {
    var dict = Dictionary()
    dict["foo0"] = .number(Number(int64: 0xdead_beef))

    let serialized = dict.serialize()

    // First 20 bytes are prefixes tested elsewhere
    var idx = 20
    XCTAssertEqual(serialized[strType: idx], "krts")
    idx += 4
    XCTAssertEqual(serialized[strType: idx], "foo0")
    idx += 8
    XCTAssertEqual(serialized[strType: idx], "vbmn")
    // TODO assert value when Number supports parsing
  }

  // TODO test parsing when supported
}
