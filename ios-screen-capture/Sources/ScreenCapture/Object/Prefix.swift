import Foundation

struct Prefix {
  static let size = 8
  // Length of the prefix and payload
  let length: UInt32
  let type: DataType

  internal init(length: UInt32, type: DataType) {
    self.length = length
    self.type = type
  }

  init?(_ data: Data) {
    if data.count < 8 {
      logger.error("Cannot parse prefix from only \(data.count) bytes!")
      return nil
    }

    length = data[uint32: 0]
    let typeStr = String(String(data: data.subdata(in: 4..<8), encoding: .ascii)!.reversed())
    type = DataType(rawValue: typeStr)!
  }

  func serialize() -> Data {
    var result = Data(count: 8)
    result.uint32(at: 0, length)
    result.copyInto(at: 4, from: String(type.rawValue.reversed()).data(using: .ascii)!)
    return result
  }
}
