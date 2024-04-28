import Foundation

typealias Dictionary = [String: DictValue]

enum DictValue {
  case bool(Bool)
  case string(String)
  case data(Data)
  indirect case dict([String: DictValue])
  case number(Number)
}

extension DictValue: Equatable {
  func serialize() -> Data {
    var result = Data()
    switch self {
    case .bool(let b):
      result.append(Swift.withUnsafeBytes(of: UInt32(Prefix.size + 1)) { Data($0) })
      result.append(DataType.bool.serialize())
      result.append(UInt8(b ? 1 : 0))
    case .dict(let d):
      let serialized = d.serialize()
      result.append(Swift.withUnsafeBytes(of: UInt32(Prefix.size + serialized.count)) { Data($0) })
      result.append(DataType.dict.serialize())
      result.append(serialized)
    case .number(let n):
      let serialized = n.serialize()
      result.append(Swift.withUnsafeBytes(of: UInt32(Prefix.size + serialized.count)) { Data($0) })
      result.append(DataType.number.serialize())
      result.append(serialized)
    // TODO more cases
    default:
      print("oh no!")
    }
    return result
  }
}

extension Dictionary {

  init?(_ data: Data) {
    self.init()
    let length = data[uint32: 0]
    guard data.count >= length else {
      logger.error(
        "Could not parse packet dictionary: Stated length of \(length) but only \(data.count) bytes!"
      )
      return nil
    }
    // TODO keep parsing
  }

  func serialize() -> Data {
    var result = Data()
    for (key, value) in self {
      let kv = serialize(key, value)
      let prefix = Prefix(length: UInt32(8 + kv.count), type: .keyValue)
      result.append(prefix.serialize())
      result.append(serialize(key, value))
    }
    var prefix = Prefix(length: UInt32(8 + result.count), type: .dict).serialize()
    prefix.append(result)
    return prefix
  }

  private func serialize(_ key: String, _ value: DictValue) -> Data {
    var result = key.serializeKey()
    result.append(value.serialize())
    return result
  }
}

extension String {
  func serializeKey() -> Data {
    let len = 8 + self.count
    var result = Data(count: len)
    result.uint32(at: 0, UInt32(len))
    result.copyInto(at: 4, from: DataType.stringKey.serialize())
    result.copyInto(at: 8, from: self.data(using: .ascii)!)
    return result
  }
}

enum DataType: String {
  case dict = "dict"
  case keyValue = "keyv"
  case stringKey = "strk"
  case bool = "bulv"
  case string = "strv"
  case data = "datv"
  case number = "nmbv"
  case formatDesc = "fdsc"
}

extension DataType {
  static func parse(from: Data) -> DataType {
    let value = String(data: Data(from.subdata(in: 0..<4).reversed()), encoding: .ascii)!
    return DataType(rawValue: value)!
  }

  func serialize() -> Data {
    String(self.rawValue.reversed()).data(using: .ascii)!
  }
}
