import Foundation

extension Data {
  subscript(uint64 idx: Int = 0) -> UInt64 {
    get {
      return self.withUnsafeBytes {
        $0.load(fromByteOffset: idx, as: UInt64.self)
      }
    }
  }

  mutating func uint64(at idx: Int, _ newValue: UInt64) {
    let bytes = Swift.withUnsafeBytes(of: newValue) { Data($0) }
    self.replaceSubrange(idx..<idx + 8, with: bytes)
  }

  subscript(uint32 idx: Int = 0) -> UInt32 {
    get {
      return self.withUnsafeBytes { $0.load(fromByteOffset: idx, as: UInt32.self) }
    }
  }

  mutating func uint32(at idx: Int, _ newValue: UInt32) {
    var bytes = [UInt8]()
    for i in 0..<4 {
      let shifted = newValue >> (8 * i)
      bytes.append(UInt8(shifted & 0xff))
    }
    self.replaceSubrange(idx..<idx + 4, with: bytes)
  }

  subscript(uint16 idx: Int = 0) -> UInt16 {
    get {
      self.withUnsafeBytes { $0.load(fromByteOffset: idx, as: UInt16.self) }
    }
  }

  mutating func uint16(at idx: Int, _ newValue: UInt16) {
    let bytes = Swift.withUnsafeBytes(of: newValue) { Data($0) }
    self.replaceSubrange(idx..<idx + 2, with: bytes)
  }

  mutating func copyInto(at startIdx: Int, from toCopy: Data) {
    let rng = startIdx..<startIdx + toCopy.count
    self.replaceSubrange(rng, with: toCopy)
  }

  mutating func copyInto(at startIdx: Int, from toCopy: String) {
    var bytes = toCopy.data(using: .ascii)!
    bytes.reverse()
    self.copyInto(at: startIdx, from: bytes)
  }

  mutating func append(_ toAdd: UInt32) {
    var toAppend = Data(capacity: 4)
    toAppend.uint32(at: 0, toAdd)
    self.append(toAppend)
  }

  mutating func append(_ toAdd: UInt8) {
    var toAppend = Data(count: 1)
    toAppend[0] = toAdd
    self.append(toAppend)
  }
}
