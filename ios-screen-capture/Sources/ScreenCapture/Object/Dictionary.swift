import Foundation

typealias Dictionary = [String: DictValue]

enum DictValue {
  case bool(Bool)
  case string(String)
  case data(Data)
  indirect case dict([String: DictValue])
  case number(Number)
  // TODO format description (fdsc)
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
    case .string(let s):
      let serialized = s.data(using: .ascii)!
      result.append(Swift.withUnsafeBytes(of: UInt32(Prefix.size + serialized.count)) { Data($0) })
      result.append(DataType.string.serialize())
      result.append(serialized)
    case .data(let d):
      result.append(Swift.withUnsafeBytes(of: UInt32(Prefix.size + d.count)) { Data($0) })
      result.append(DataType.data.serialize())
      result.append(d)
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
    var idx = 0
    guard let dictPrefix = Prefix(data) else { return nil }
    idx += 8
    while idx < dictPrefix.length {
      guard let kvPrefix = Prefix(data.from(idx)), kvPrefix.type == .keyValue else { return nil }
      idx += 8

      guard let keyPrefix = Prefix(data.from(idx)), keyPrefix.type == .stringKey else { return nil }
      let keyRange = (idx + 8)..<(idx + Int(keyPrefix.length))
      let keyData = data.subdata(in: keyRange)
      let key = String(data: keyData, encoding: .ascii)!
      idx += Int(keyPrefix.length)

      guard let valuePrefix = Prefix(data.from(idx)) else { return nil }
      let valueRange = (idx + 8)..<(idx + Int(valuePrefix.length))
      let valueData = data.subdata(in: valueRange)
      switch valuePrefix.type {
      case .dict:
        guard let subdict = Dictionary(valueData) else { return nil }
        self[key] = .dict(subdict)
      case .data:
        self[key] = .data(valueData)
      case .bool:
        self[key] = .bool(valueData[0] != 0)
      case .string:
        guard let str = String(data: valueData, encoding: .ascii) else { return nil }
        self[key] = .string(str)
      case .number, .formatDesc:
        // TODO
        logger.error("TODO")
      case .keyValue, .stringKey:
        // These types should never appear for dict values
        return nil
      }
      idx += Int(valuePrefix.length)
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
