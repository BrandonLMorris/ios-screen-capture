import Foundation
import Testing

final class TimeTests {
  let fixture = "4eFCxGK6AAAAypo7AQAAAAAAAAAAAAAA"

  @Test func fixtureParsing() throws {
    let time = Time(Data(base64Encoded: fixture)!)!

    #expect(time.value == UInt64(0xBA62_C442_E1E1))
    #expect(time.scale == UInt32(1_000_000_000))
    #expect(time.flags == UInt32(0x01))
    #expect(time.epoch == UInt64(0))
  }

  @Test func serializeBackToFixture() throws {
    let time = Time(Data(base64Encoded: fixture)!)!

    let serialized = time.serialize()

    #expect(serialized.base64EncodedString() == fixture)
  }
}
