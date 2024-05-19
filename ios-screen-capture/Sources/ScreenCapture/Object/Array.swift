import Foundation

/// Similar to `Dictionary`, an associative collection of packet data objects.
/// All keys are integers, but is **not** a contiguous collection like a
/// C-style array; that is, an element at index N does **not** mean indices 0
/// to N-1 are set.
internal class Array {
  private var backingMap = [Int:DictValue]()
  
  init() {}

  /// Attempt to construct an `Array` from its binary representation.
  init?(_ data: Data) {
    // TODO
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
  
  private func serialize(_ k: Int, _ v: DictValue) -> Data {
    var result = serialize(index: k)
    result.append(v.serialize())
    return result
  }
  
  private func serialize(index idx: Int) -> Data {
    let len = 12 // = 4b length + 4b type id + 4b content (the index itself)
    var result = Data(count: len)
    result.uint32(at: 0, UInt32(len))
    result.copyInto(at: 4, from: DataType.indexKey.serialize())
    result.uint32(at: 8, UInt32(idx))
    return result
  }
}
