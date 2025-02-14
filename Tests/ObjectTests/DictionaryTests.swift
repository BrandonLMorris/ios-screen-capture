import Foundation
import Testing

@testable import Object

final class DictionaryTests {

  @Test func serializeDictWithStringValue() throws {
    var dict = Dictionary()
    dict["foo"] = .string("bar")

    let serialized = dict.serialize()

    #expect(serialized[strType: 4] == "tcid")
    #expect(serialized[strType: 12] == "vyek")
    #expect(serialized[strType: 20] == "krts")
    // Note: The actual values aren't endian-ed
    #expect(String(data: serialized.subdata(in: 24..<27), encoding: .ascii)! == "foo")
    // 27 + 4b length = 31
    #expect(serialized[strType: 31] == "vrts")
    #expect(String(data: serialized.subdata(in: 35..<38), encoding: .ascii)! == "bar")
  }

  @Test func serializeDictWithBoolValues() throws {
    var dict = Dictionary()
    dict["t"] = .bool(true)
    dict["f"] = .bool(false)

    let serialized = dict.serialize()

    // First 20 bytes are prefixes tested elsewhere
    var idx = 20
    // There are two elements, but since we're iterating over the
    // underlying dictionary we can't assume order.
    for _ in 0..<2 {
      #expect(serialized[strType: idx] == "krts")
      idx += 4
      if serialized[idx] == Character("t").asciiValue! {
        idx += 5
        #expect(serialized[strType: idx] == "vlub")
        idx += 4
        #expect(serialized[idx] == UInt8(1))
      } else if serialized[idx] == Character("f").asciiValue! {
        idx += 5
        #expect(serialized[strType: idx] == "vlub")
        idx += 4
        #expect(serialized[idx] == UInt8(0))
      } else {
        Issue.record("Key at index \(idx) not found!")
        return
      }
      idx += 13
    }
  }

  @Test func serializeDictWithDictValue() throws {
    var nested = Dictionary()
    nested["foo0"] = .string("bar0")
    var dict = Dictionary()
    dict["key1"] = .dict(nested)

    let serialized = dict.serialize()

    // First 20 bytes are prefixes tested elsewhere
    var idx = 20
    #expect(serialized[strType: idx] == "krts")
    idx += 4
    #expect(serialized[strType: idx] == "key1")
    idx += 8
    #expect(serialized[strType: idx] == "tcid")  // value type
    idx += 8
    #expect(serialized[strType: idx] == "vyek")  // prefix of dict value
    idx += 8
    #expect(serialized[strType: idx] == "krts")
    idx += 4
    #expect(serialized[strType: idx] == "foo0")
    idx += 8
    #expect(serialized[strType: idx] == "vrts")
    idx += 4
    #expect(serialized[strType: idx] == "bar0")
  }

  @Test func serializeDictWithNumberValue() throws {
    var dict = Dictionary()
    dict["foo0"] = .number(Number(int64: 0xdead_beef))

    let serialized = dict.serialize()

    // First 20 bytes are prefixes tested elsewhere
    var idx = 20
    #expect(serialized[strType: idx] == "krts")
    idx += 4
    #expect(serialized[strType: idx] == "foo0")
    idx += 8
    #expect(serialized[strType: idx] == "vbmn")
    // TODO: Assert value when Number supports parsing
  }

  @Test func serializeDictWithDataValue() throws {
    let data = Data([0xde, 0xad, 0xbe, 0xef])
    var dict = Dictionary()
    dict["foo0"] = .data(data)

    let serialized = dict.serialize()

    var idx = 32
    #expect(serialized[strType: idx] == "vtad")
    idx += 4
    #expect(serialized.subdata(in: idx..<serialized.count) == data)
  }

  @Test func parsingDictionaryWithStringValue() throws {
    var dict = Dictionary()
    let strValue: DictValue = .string("bar0")
    dict["foo0"] = strValue
    let serialized = dict.serialize()

    let parsed = Dictionary(serialized)!

    #expect(parsed["foo0"]! == strValue)
  }

  @Test func parsingDictionaryWithDataValue() throws {
    let data: DictValue = .data(Data([0xde, 0xad, 0xbe, 0xef]))
    var dict = Dictionary()
    dict["foo0"] = data
    let serialized = dict.serialize()

    let parsed = Dictionary(serialized)!

    #expect(parsed["foo0"]! == data)
  }

  @Test func parsingDictionaryWithBoolValue() {
    let b: DictValue = .bool(true)
    var dict = Dictionary()
    dict["foo0"] = b
    let serialized = dict.serialize()

    let parsed = Dictionary(serialized)!

    #expect(parsed["foo0"]! == b)
  }

  @Test func parsingDictionaryWithMultipleValues() {
    let b: DictValue = .bool(true)
    let data: DictValue = .data(Data([0xde, 0xad, 0xbe, 0xef]))
    var dict = Dictionary()
    dict["foo0"] = b
    dict["dat0"] = data
    let serialized = dict.serialize()

    let parsed = Dictionary(serialized)!

    #expect(parsed["foo0"]! == b)
    #expect(parsed["dat0"]! == data)
  }

  @Test func parsingNestedDictionaries() {
    var nested = Dictionary()
    nested["foo0"] = .string("bar0")
    var dict = Dictionary()
    dict["dict"] = .dict(nested)
    let serialized = dict.serialize()

    let parsed = Dictionary(serialized)!

    if case let .dict(parsedNested) = parsed["dict"]! {
      #expect(parsedNested == nested)
    } else {
      Issue.record("Failed to parse nested dictionay")
    }
  }

  @Test func parsingFixture() throws {
    let fixture =
      "xwAAAHRjaWQgAAAAdnllaw8AAABrcnRzVmFsZXJpYQkAAAB2bHViAS8AAAB2eWVrHgAAAGtydHNIRVZDRGVjb2RlclN1cHBvcnRzNDQ0CQAAAHZsdWIBcAAAAHZ5ZWsTAAAAa3J0c0Rpc3BsYXlTaXplVQAAAHRjaWQmAAAAdnllaw0AAABrcnRzV2lkdGgRAAAAdmJtbgYAAAAAAACeQCcAAAB2eWVrDgAAAGtydHNIZWlnaHQRAAAAdmJtbgYAAAAAAMCSQA=="
    let binary = Data(base64Encoded: fixture)!

    #expect(Dictionary(binary) != nil)
  }

  @Test func parsingComplexFixture() throws {
    let fixture =
      "ZQIAAHRjaWTHAAAAdnllayMAAABrcnRzUHJlcGFyZWRRdWV1ZUhpZ2hXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EBQAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAAxgAAAHZ5ZWsiAAAAa3J0c1ByZXBhcmVkUXVldWVMb3dXYXRlckxldmVsnAAAAHRjaWQiAAAAdnllaw0AAABrcnRzZmxhZ3MNAAAAdmJtbgMBAAAAJgAAAHZ5ZWsNAAAAa3J0c3ZhbHVlEQAAAHZibW4EAwAAAAAAAAAmAAAAdnllaxEAAABrcnRzdGltZXNjYWxlDQAAAHZibW4DHgAAACYAAAB2eWVrDQAAAGtydHNlcG9jaBEAAAB2Ym1uBAAAAAAAAAAA0AAAAHZ5ZWsZAAAAa3J0c0Zvcm1hdERlc2NyaXB0aW9urwAAAGNzZGYMAAAAYWlkbWVkaXYQAAAAbWlkdmYEAACECQAADAAAAGNkb2MxY3ZhfwAAAG50eGVYAAAAdnllawoAAABreGRpMQBGAAAAdGNpZD4AAAB2eWVrCgAAAGt4ZGlpACwAAAB2dGFkAWQAM//hABEnZAAzrFaARwEz5p5uBAQEBAEABCjuPLD9+PgAHwAAAHZ5ZWsKAAAAa3hkaTQADQAAAHZydHNILjI2NA=="
    let binary = Data(base64Encoded: fixture)!

    #expect(Dictionary(binary) != nil)
  }
}
