import Foundation

struct Number: Equatable {
  private var type: NumberType = .int64
  private var int32Value = UInt32(0)
  private var int64Value = UInt64(0)
  private var float64Value = Float64()

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
    // TODO
    return nil
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
