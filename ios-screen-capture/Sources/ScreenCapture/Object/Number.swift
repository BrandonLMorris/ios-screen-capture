import Foundation

struct Number: Equatable {
  private var type: NumberType = .int64
  private(set) var int32Value = UInt32(0)
  private(set) var int64Value = UInt64(0)
  private(set) var float64Value = Float64()

  private enum NumberType: UInt8 {
    case int32 = 3
    case int64 = 4
    case float64 = 6
  }

  init(int32: UInt32) {
    type = .int32
    int32Value = int32
  }

  init(int64: UInt64) {
    type = .int64
    int64Value = int64
  }

  init(float64: Float64) {
    type = .float64
    float64Value = float64
  }

  init?(_ data: Data) {
    // Minimum possible length (when uint32 value)
    guard data.count >= 12 else { return nil }
    guard data.prefix(4) == DataType.number.serialize() else { return nil }
    let numType = UInt8(data[uint32: 4])
    switch numType {
    case NumberType.int32.rawValue:
      self.int32Value = data[uint32: 8]
    case NumberType.int64.rawValue:
      guard data.count >= 16 else { return nil }
      self.int64Value = data[uint64: 8]
    case NumberType.float64.rawValue:
      guard data.count >= 16 else { return nil }
      self.float64Value = data[float64: 8]
    default:
      return nil
    }
  }

  func serialize() -> Data {
    var result = Data()
    result.append(DataType.number.serialize())
    result.append(UInt32(self.type.rawValue))
    switch self.type {
    case .int32:
      result.append(withUnsafeBytes(of: int32Value) { Data($0) })
    case .int64:
      result.append(withUnsafeBytes(of: int64Value) { Data($0) })
    case .float64:
      result.append(withUnsafeBytes(of: float64Value) { Data($0) })
    }
    return result
  }
}
