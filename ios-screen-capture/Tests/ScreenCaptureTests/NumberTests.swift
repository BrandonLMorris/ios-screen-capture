import Testing

final class NumberTests {

  @Test func serializeNumberWithInt32Value() throws {
    let val = UInt32(42)
    let serialized = Number(int32: val).serialize()

    #expect(serialized.count == 13)
    #expect(serialized[strType: 4] == "vbmn")
    #expect(serialized[8] == UInt8(3))
    #expect(serialized[uint32: 9] == UInt32(42))
  }

  @Test func serializeNumberWithInt64Value() throws {
    let val = UInt64(2 << 64)
    let n = Number(int64: val)

    let serialized = n.serialize()

    #expect(serialized.count == 17)
    #expect(serialized[strType: 4] == "vbmn")
    #expect(serialized[8] == UInt8(4))
    #expect(serialized[uint64: 9] == val)
  }

  @Test func serializeNumberWithFloat64Value() throws {
    let val = Float64(3.14)
    let n = Number(float64: val)

    let serialized = n.serialize()

    #expect(serialized.count == 17)
    #expect(serialized[strType: 4] == "vbmn")
    #expect(serialized[8] == UInt8(6))
    // FIXME: Using the right method
    let valueDiff = abs(serialized[float64: 9] - val)
    #expect(valueDiff < 1e-5)
  }

  @Test func parseNumberWithInt32Value() throws {
    let parsed = Number(Number(int32: 42).serialize())!

    #expect(parsed.int32Value == 42)
  }

  @Test func parseNumberWithInt64Value() throws {
    let v = UInt64(2 << 63)
    let parsed = Number(Number(int64: v).serialize())!

    #expect(parsed.int64Value == v)
  }

  @Test func parseNumberWithFloat64Value() throws {
    let e = 2.72
    let parsed = Number(Number(float64: 2.72).serialize())!

    let diff = abs(parsed.float64Value - e)
    #expect(diff < 1e-5)
  }
}
