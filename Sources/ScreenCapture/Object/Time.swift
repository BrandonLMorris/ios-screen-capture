import CoreMedia
import Foundation

private let nanosPerSecond = 1_000_000_000

/// A representation of time.
///
/// Roughly analogous to the Core Media type CMTime.
public struct Time: Equatable {
  internal let value: UInt64
  internal let scale: UInt32
  internal let flags: UInt32
  internal let epoch: UInt64

  private static let valueIdx = 0
  private static let scaleIdx = 8
  private static let flagsIdx = 12
  private static let epochIdx = 16

  internal static let size = 24
  nonisolated(unsafe) public static let NULL = Time(Data(count: size))

  init?(_ data: Data) {
    self.value = data[uint64: Time.valueIdx]
    self.scale = data[uint32: Time.scaleIdx]
    self.flags = data[uint32: Time.flagsIdx]
    self.epoch = data[uint64: Time.epochIdx]
  }

  internal init(value: UInt64, scale: UInt32) {
    self.value = value
    self.scale = scale
    (self.flags, self.epoch) = (0, 0)
  }

  public init(nanoseconds: UInt64) {
    self.value = nanoseconds
    self.scale = UInt32(nanosPerSecond)
    self.flags = 1
    self.epoch = 0
  }

  public func serialize() -> Data {
    var toReturn = Data(count: 24)
    toReturn.uint64(at: Time.valueIdx, value)
    toReturn.uint32(at: Time.scaleIdx, scale)
    toReturn.uint32(at: Time.flagsIdx, flags)
    toReturn.uint64(at: Time.epochIdx, epoch)
    return toReturn
  }

  public static func now() -> Time {
    return Time(nanoseconds: DispatchTime.now().uptimeNanoseconds)
  }

  func toNanos() -> Time {
    if self.scale == UInt32(nanosPerSecond) {
      return self
    }
    let newValue = Float(self.value) * Float(nanosPerSecond) / Float(self.scale)
    return Time(nanoseconds: UInt64(newValue))
  }

  func rescale(to newScale: UInt32) -> Time {
    if self.scale == newScale { return self }
    let scaleFactor = Double(newScale) / Double(self.scale)
    let newValue = Double(self.value) * scaleFactor
    return Time(value: UInt64(newValue), scale: newScale)
  }

  public func since(_ other: Time) -> Time {
    return Time(nanoseconds: value - other.toNanos().value)
  }
}

public func skew(localDuration: Time, deviceDuration: Time) -> Float64 {
  let scaledDiff = localDuration.rescale(to: deviceDuration.scale)
  return Double(scaledDiff.value) * Double(deviceDuration.scale) / Double(deviceDuration.value)
}

extension Time {
  func toCMTime() -> CMTime {
    CMTimeMakeWithEpoch(
      value: Int64(self.value), timescale: Int32(self.scale), epoch: Int64(self.epoch))
  }
}

extension TimingData {
  func toCMTimingInfo() -> CMSampleTimingInfo {
    CMSampleTimingInfo(
      duration: self.duration.toCMTime(),
      presentationTimeStamp: self.presentation.toCMTime(),
      decodeTimeStamp: self.decode.toCMTime()
    )
  }
}
