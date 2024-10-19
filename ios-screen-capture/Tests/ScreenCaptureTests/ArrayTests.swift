import Foundation
import Testing

final class ArrayTests {

  @Test func returnsIndexValue() throws {
    let v: DictValue = .string("big summer blowout")
    let arr = Array()
    arr[555] = v

    #expect(arr[555] == v)
  }

  @Test func indexAbsentReturnsNil() throws {
    #expect(Array()[42] == nil)
  }

  @Test func serializeSimple() throws {
    let arr = Array()
    arr[42] = .string("foo")

    let serialized = arr.serialize()

    #expect(serialized[strType: 4] == "tcid")
    #expect(serialized[strType: 12] == "vyek")
    #expect(serialized[strType: 20] == "kxdi")
    #expect(serialized[uint16: 24] == UInt16(42))
    // 26 + 4b length = 30
    #expect(serialized[strType: 30] == "vrts")
    #expect(String(data: serialized.subdata(in: 34..<37), encoding: .ascii)! == "foo")
  }

  @Test func serializeMultipleValues() throws {
    let arr = Array()
    arr[12345] = .string("abcd")
    arr[45678] = .string("efgh")

    let serialized = arr.serialize()

    var idx = 4
    #expect(serialized[strType: idx] == "tcid")
    idx += 4
    // We serialize in sorted key order, so its safe (for testing) to assume
    // the serialized order.
    for (k, v) in [(UInt16(12345), "abcd"), (UInt16(45678), "efgh")] {
      // Key-value prefix
      #expect(serialized[strType: (idx + 4)] == "vyek")
      idx += 8

      // Index
      #expect(serialized[strType: (idx + 4)] == "kxdi")
      idx += 8
      #expect(serialized[uint16: idx] == k)
      idx += 2

      // Value
      #expect(serialized[strType: (idx + 4)] == "vrts")
      idx += 8
      #expect(String(data: serialized.subdata(in: idx..<(idx + 4)), encoding: .ascii)! == v)
      idx += 4
    }
  }

  @Test func parsingWithStringValue() throws {
    let arr = Array()
    let strValue: DictValue = .string("bar0")
    arr[52] = strValue
    let serialized = arr.serialize()

    let parsed = Array(serialized)!

    #expect(parsed[52]! == strValue)
  }

  @Test func parsingWithMultipleValues() throws {
    let arr = Array()
    let num = Number(float64: 3.14159)
    let strValue: DictValue = .string("veryveryveryverylongstring")
    arr[123] = .number(num)
    arr[456] = strValue
    let serialized = arr.serialize()

    let parsed = Array(serialized)!

    guard case let .number(n) = parsed[123]! else {
      Issue.record("Expected number value at index 123")
      return
    }
    #expect(floatNumbersAlmostEqual(n1: n, n2: num))
    #expect(parsed[456]! == strValue)
  }

  @Test func parsingAllValueTypes() throws {
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
      #expect(parsed[i] == arr[i])
    }
  }

  @Test func arrayEquality() throws {
    let arr1 = Array()
    arr1[500] = .string("foo")
    arr1[505] = .string("bar")

    let arr2 = Array()
    arr2[500] = .string("foo")

    #expect(arr1 == arr1)
    #expect(arr1 != Array())
    #expect(arr1 != arr2)

    arr2[505] = .string("bar")
    #expect(arr1 == arr2)
  }

  @Test func nestedArray() throws {
    let arr = Array()
    let nested = Array()
    nested[48879] = .string("foo0")
    arr[255] = .array(nested)

    let serialized = arr.serialize()
    let reserialized = Array(serialized)!.serialize()
    #expect(serialized == reserialized)
  }

  @Test func multipleNestedArrays() throws {
    let arr1 = Array()
    arr1[0] = .bool(true)
    let arr2 = Array()
    arr2[0] = .string("bar0")
    let arr = Array()
    arr[0] = .array(arr1)
    let serialized = arr.serialize()

    let parsed = Array(serialized)!

    #expect(parsed.serialize() == serialized)
  }

  private func floatNumbersAlmostEqual(n1: Number, n2: Number) -> Bool {
    let diff = abs(n1.float64Value - n2.float64Value)
    return diff < 1e-5
  }
}
