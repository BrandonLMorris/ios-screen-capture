import Foundation

/// Similar to `Dictionary`, an associative collection of packet data objects.
/// All keys are integers, but is **not** a contiguous collection like a
/// C-style array; that is, an element at index N does **not** mean indices 0
/// to N-1 are set.
internal class Array: Equatable {

  private var backingMap = [Int: DictValue]()

  init() {}

  /// Attempt to construct an `Array` from its binary representation.
  init?(_ data: Data) {
    // TODO Merge with dictionary parsing
    let length = data[uint32: 0]
    guard data.count >= length else {
      logger.error(
        "Could not parse packet array: Stated length of \(length) but only \(data.count) bytes!"
      )
      return nil
    }

    var idx = 0
    guard let arrPrefix = Prefix(data) else { return nil }
    idx += Prefix.size
    while idx < arrPrefix.length {
      // Key-value
      let kvPrefix = Prefix(data.from(idx))
      guard kvPrefix?.type == .keyValue else { return nil }
      idx += Prefix.size

      // Key
      guard let keyPrefix = Prefix(data.from(idx)), keyPrefix.type == .indexKey else { return nil }
      idx += Prefix.size
      let key = Int(data[uint32: idx])
      idx += 4  // uint32

      // Value
      guard let valuePrefix = Prefix(data.from(idx)) else { return nil }
      let valueRange = (idx + 8)..<(idx + Int(valuePrefix.length))
      let valueData = data.subdata(in: valueRange)
      switch valuePrefix.type {
      case .dict:
        if let subdict = Dictionary(data.from(idx)) {
          backingMap[key] = .dict(subdict)
        } else if let nested = Array(data.from(idx)) {
          backingMap[key] = .array(nested)
        } else {
          return nil
        }
      case .data:
        backingMap[key] = .data(valueData)
      case .bool:
        backingMap[key] = .bool(valueData[0] != 0)
      case .string:
        guard let str = String(data: valueData, encoding: .ascii) else { return nil }
        backingMap[key] = .string(str)
      case .number:
        guard let num = Number(valueData) else { return nil }
        backingMap[key] = .number(num)
      case .formatDesc:
        // TODO
        logger.error("TODO")
      case .keyValue, .stringKey, .indexKey:
        // These types should never appear for dict values
        return nil
      }
      idx += Int(valuePrefix.length)
    }
  }

  /// Convert this `Array` to its binary format.
  func serialize() -> Data {
    var result = Data()
    let keys = backingMap.keys.sorted()
    for k in keys {
      let v = backingMap[k]!
      let kv = serialize(k, v)
      let prefix = Prefix(length: UInt32(8 + kv.count), type: .keyValue)
      result.append(prefix.serialize())
      result.append(kv)
    }
    var prefix = Prefix(length: UInt32(8 + result.count), type: .dict).serialize()
    prefix.append(result)
    return prefix
  }

  /// Subscript to mimic the interface of a conventional array.
  subscript(_ idx: Int) -> DictValue? {
    get {
      guard let value = backingMap[idx] else { return nil }
      return value
    }
    set {
      backingMap[idx] = newValue
    }
  }

  static func == (lhs: Array, rhs: Array) -> Bool {
    let leftKeys = lhs.backingMap.keys.sorted()
    for k in leftKeys {
      guard let l = lhs.backingMap[k], let r = rhs.backingMap[k], l == r else { return false }
    }
    return true
  }

  private func serialize(_ k: Int, _ v: DictValue) -> Data {
    var result = serialize(index: k)
    result.append(v.serialize())
    return result
  }

  private func serialize(index idx: Int) -> Data {
    let len = 12  // = 4b length + 4b type id + 4b content (the index itself)
    var result = Data(count: len)
    result.uint32(at: 0, UInt32(len))
    result.copyInto(at: 4, from: DataType.indexKey.serialize())
    result.uint32(at: 8, UInt32(idx))
    return result
  }
}
