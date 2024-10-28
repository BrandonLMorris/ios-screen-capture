import Foundation

private let nanosPerSecond = 1_000_000_000

/// A representation of time.
///
/// Roughly analogous to the Core Media type CMTime.
struct Time {
  internal let value: UInt64
  internal let scale: UInt32
  internal let flags: UInt32
  internal let epoch: UInt64

  private let valueIdx = 0
  private let scaleIdx = 8
  private let flagsIdx = 12
  private let epochIdx = 16

  internal static let size = 24
  internal static let NULL = Time(Data(count: size))

  init?(_ data: Data) {
    self.value = data[uint64: valueIdx]
    self.scale = data[uint32: scaleIdx]
    self.flags = data[uint32: flagsIdx]
    self.epoch = data[uint64: epochIdx]
  }

  internal init(value: UInt64, scale: UInt32) {
    self.value = value
    self.scale = scale
    (self.flags, self.epoch) = (0, 0)
  }

  init(nanoseconds: UInt64) {
    self.value = nanoseconds
    self.scale = UInt32(nanosPerSecond)
    self.flags = 1
    self.epoch = 0
  }

  func serialize() -> Data {
    var toReturn = Data(count: 24)
    toReturn.uint64(at: valueIdx, value)
    toReturn.uint32(at: scaleIdx, scale)
    toReturn.uint32(at: flagsIdx, flags)
    toReturn.uint64(at: epochIdx, epoch)
    return toReturn
  }

  static func now() -> Time {
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

  func since(_ other: Time) -> Time {
    return Time(nanoseconds: value - other.toNanos().value)
  }
}

internal func skew(localDuration: Time, deviceDuration: Time) -> Float64 {
  let scaledDiff = localDuration.rescale(to: deviceDuration.scale)
  return Double(scaledDiff.value) * Double(deviceDuration.scale) / Double(deviceDuration.value)
}
