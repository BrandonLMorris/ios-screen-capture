import Foundation
import Testing

@testable import Object

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

  @Test func nanosecondConstructorConsistent() throws {
    let time = Time(value: 12_345_678, scale: 1_000_000_000)
    let time2 = Time(nanoseconds: 12_345_678)

    #expect(time.toNanos().value == time2.toNanos().value)
  }

  @Test func nowUsesNanoseconds() throws {
    let rightNow = Time.now()

    #expect(rightNow.value > 0)
    #expect(rightNow.scale == 1_000_000_000)
  }

  @Test func cmTimeIsValid() throws {
    #expect(Time.now().toCMTime().isValid)
  }

  @Test func rescalingWorks() throws {
    let fps = Time(value: 60, scale: 1)
    let rescaled = fps.rescale(to: 100)

    #expect(rescaled.scale == 100)
    #expect(rescaled.value == 6000)
  }
}

final class SkewTests {
  @Test func calculateNoSkew() {
    let local = Time(value: UInt64(1), scale: UInt32(48000))
    let device = Time(value: UInt64(1), scale: UInt32(48000))

    expectClose(skew(localDuration: local, deviceDuration: device), 48000)
  }

  @Test func calculateSomeSkew() {
    let local = Time(value: UInt64(2), scale: UInt32(48000))
    let device = Time(value: UInt64(1), scale: UInt32(48000))

    expectClose(skew(localDuration: local, deviceDuration: device), 96000)
  }

  @Test func calculateSomeNegativeSkew() {
    let local = Time(value: UInt64(2000), scale: UInt32(48000))
    let device = Time(value: UInt64(2001), scale: UInt32(48000))

    expectClose(skew(localDuration: local, deviceDuration: device), 47976.011994003)
  }
}

func expectClose(_ first: Float64, _ second: Float64) {
  #expect(abs(first - second) < 1e-5)
}
