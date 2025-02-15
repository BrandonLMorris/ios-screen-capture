import CoreMedia
import Foundation

extension Data {
  public subscript(strType idx: Int) -> String {
    String(data: self.subdata(in: idx..<idx + 4), encoding: .ascii)!
  }

  public subscript(uint64 idx: Int = 0) -> UInt64 {
    get {
      return self.withUnsafeBytes {
        let base = $0.baseAddress!.advanced(by: idx)
        var toReturn: UInt64 = 0
        memcpy(&toReturn, base, MemoryLayout<UInt64>.size)
        return toReturn
      }
    }
  }

  public mutating func uint64(at idx: Int, _ newValue: UInt64) {
    let bytes = Swift.withUnsafeBytes(of: newValue) { Data($0) }
    self.replaceSubrange(idx..<idx + 8, with: bytes)
  }

  public subscript(uint32 idx: Int = 0) -> UInt32 {
    get {
      return self.withUnsafeBytes { bufferPtr in
        let start = bufferPtr.baseAddress!.advanced(by: idx)
        var toReturn: UInt32 = 0
        memcpy(&toReturn, start, MemoryLayout<UInt32>.size)
        return toReturn
      }
    }
  }

  public mutating func uint32(at idx: Int, _ newValue: UInt32) {
    let bytes = Swift.withUnsafeBytes(of: newValue) { Data($0) }
    self.replaceSubrange(idx..<idx + 4, with: bytes)
  }

  public subscript(uint16 idx: Int = 0) -> UInt16 {
    get {
      self.withUnsafeBytes {
        let base = $0.baseAddress!.advanced(by: idx)
        var toReturn: UInt16 = 0
        memcpy(&toReturn, base, MemoryLayout<UInt16>.size)
        return toReturn
      }
    }
  }

  public mutating func uint16(at idx: Int, _ newValue: UInt16) {
    let bytes = Swift.withUnsafeBytes(of: newValue) { Data($0) }
    self.replaceSubrange(idx..<idx + 2, with: bytes)
  }

  public subscript(float64 idx: Int = 0) -> Float64 {
    get {
      self.withUnsafeBytes {
        let base = $0.baseAddress!.advanced(by: idx)
        var toReturn: Float64 = 0.0
        memcpy(&toReturn, base, MemoryLayout<Float64>.size)
        return toReturn
      }
    }
  }

  public mutating func float64(at idx: Int, _ newValue: Float64) {
    let bytes = Swift.withUnsafeBytes(of: newValue) { Data($0) }
    self.replaceSubrange(idx..<idx + 8, with: bytes)
  }

  public mutating func copyInto(at startIdx: Int, from toCopy: Data) {
    let rng = startIdx..<startIdx + toCopy.count
    self.replaceSubrange(rng, with: toCopy)
  }

  public mutating func copyInto(at startIdx: Int, from toCopy: String) {
    var bytes = toCopy.data(using: .ascii)!
    bytes.reverse()
    self.copyInto(at: startIdx, from: bytes)
  }

  public mutating func append(_ toAdd: UInt32) {
    var toAppend = Data(count: 4)
    toAppend.uint32(at: 0, toAdd)
    self.append(toAppend)
  }

  public mutating func append(_ toAdd: UInt8) {
    var toAppend = Data(count: 1)
    toAppend[0] = toAdd
    self.append(toAppend)
  }

  public func from(_ idx: Int) -> Data {
    self.subdata(in: idx..<self.count)
  }

  public var blockBuffer: CMBlockBuffer {
    let cfData = self as CFData
    let dataLength = CFDataGetLength(cfData)
    var blockBuffer: CMBlockBuffer?
    CMBlockBufferCreateWithMemoryBlock(
      allocator: kCFAllocatorDefault,
      memoryBlock: nil,  // Core Foundation will allocate for us
      blockLength: dataLength, blockAllocator: kCFAllocatorDefault,
      customBlockSource: nil, offsetToData: 0, dataLength: dataLength, flags: 0,
      blockBufferOut: &blockBuffer)
    CMBlockBufferReplaceDataBytes(
      with: CFDataGetBytePtr(cfData), blockBuffer: blockBuffer!, offsetIntoDestination: 0,
      dataLength: dataLength)
    return blockBuffer!
  }
}
