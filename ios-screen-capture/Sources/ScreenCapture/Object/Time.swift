import Foundation

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
    value = data[uint64: valueIdx]
    scale = data[uint32: scaleIdx]
    flags = data[uint32: flagsIdx]
    epoch = data[uint64: epochIdx]
  }

  func serialize() -> Data {
    var toReturn = Data(count: 24)
    toReturn.uint64(at: valueIdx, value)
    toReturn.uint32(at: scaleIdx, scale)
    toReturn.uint32(at: flagsIdx, flags)
    toReturn.uint64(at: epochIdx, epoch)
    return toReturn
  }
}
