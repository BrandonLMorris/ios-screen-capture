import Foundation

public struct Number: Equatable {
  private var type: NumberType = .int64
  private(set) var int32Value = UInt32(0)
  private(set) var int64Value = UInt64(0)
  private(set) var float64Value = Float64()

  private enum NumberType: UInt8 {
    case int32 = 3
    case int64 = 4
    case float64 = 6
  }

  public init(int32: UInt32) {
    self.type = .int32
    self.int32Value = int32
  }

  public init(int64: UInt64) {
    self.type = .int64
    self.int64Value = int64
  }

  public init(float64: Float64) {
    self.type = .float64
    self.float64Value = float64
  }

  init?(_ data: Data) {
    // Minimum possible length (when uint32 value)
    guard data.count >= 13 else { return nil }
    let foo = data[strType: 4]
    guard foo == String(DataType.number.rawValue.reversed()) else { return nil }
    let numType = data[8]
    switch numType {
    case NumberType.int32.rawValue:
      self.int32Value = data[uint32: 9]
    case NumberType.int64.rawValue:
      guard data.count >= 17 else { return nil }
      self.int64Value = data[uint64: 9]
    case NumberType.float64.rawValue:
      guard data.count >= 17 else { return nil }
      self.float64Value = data[float64: 9]
    default:
      return nil
    }
  }

  func serialize() -> Data {
    var result = Data()
    let lenMap: [NumberType: UInt32] = [.int32: 13, .int64: 17, .float64: 17]
    result.append(lenMap[self.type]!)
    result.append(DataType.number.serialize())
    result.append(self.type.rawValue)
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
