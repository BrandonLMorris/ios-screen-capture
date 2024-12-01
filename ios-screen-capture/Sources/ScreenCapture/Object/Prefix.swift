import Foundation
import Logging

private let logger = Logger(label: "Prefix")

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
      logger.warning("Cannot parse prefix from only \(data.count) bytes!")
      return nil
    }
    self.length = data[uint32: 0]
    let typeSlice = Data(data.subdata(in: 4..<8))
    let typeStr = String(String(data: typeSlice, encoding: .ascii)!.reversed())
    if let dataType = DataType(rawValue: typeStr) {
      self.type = dataType
    } else {
      self.type = .other
    }
  }

  func serialize() -> Data {
    var result = Data(count: 8)
    result.uint32(at: 0, length)
    result.copyInto(at: 4, from: String(type.rawValue.reversed()).data(using: .ascii)!)
    return result
  }
}
