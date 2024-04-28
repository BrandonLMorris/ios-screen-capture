import Foundation
import os.log

protocol ScreenCapturePacket: CustomStringConvertible {
  var header: Header { get }
  var data: Data { get }
  var isValid: Bool { get }
}

class PacketParser {
  // Not instantiable
  private init() {}

  static func parse(from payload: Data) throws -> any ScreenCapturePacket {
    guard let header = Header(payload) else {
      throw PacketParseError.invalidHeader(
        "Unable to parse header! \(payload.base64EncodedString())")
    }
    switch header.type {
    case .ping:
      let ping = Ping(header: header, data: payload)!
      if case let ping = Ping(header: header, data: payload), ping != nil, !ping!.isValid {
        throw PacketParseError.generic(
          "Invalid ping packet detected! \(payload.base64EncodedString())")
      }
      return ping
    case .sync:
      logger.info("Received SYNC packet")
      switch header.subtype {
      case .none:
        throw PacketParseError.generic("sync packet did not have a subtype!")
      case .cwpa:
        let audioClock = AudioClock(header: header, data: payload)
        if let audioClock = audioClock, audioClock.isValid {
          return audioClock
        }
        throw PacketParseError.generic(
          "Could not parse audio clock: \(String(describing: audioClock))")
      case .hpd1:
        // Should only be sent
        throw PacketParseError.generic("Unexpected HPD1 packet")
      }
    case .async:
      throw PacketParseError.generic("TODO")
    case .reply:
      logger.error("Reply packets are only sent! Not parsing")
      return Ping.instance
    }
  }
}

struct Header: Equatable {
  let length: Int
  let type: PacketType
  let subtype: PacketSubtype

  private let minLength = 8
  private static let typeRange = 4..<8
  private static let subtypeRange = 16..<20

  var serialized: Data {
    let hasSubtype = subtype != .none
    var res = Data(count: hasSubtype ? 20 : 8)
    res.uint32(at: 0, UInt32(length))
    res.copyInto(at: 4, from: type.rawValue)
    if hasSubtype {
      res.copyInto(at: 16, from: subtype.rawValue)
    }
    return res
  }

  internal init(length: Int, type: PacketType, subtype: PacketSubtype = .none) {
    self.length = length
    self.type = type
    self.subtype = subtype
  }

  public init?(_ source: Data) {
    if source.count < minLength {
      logger.error("Failed to parse packet header: Not enough data (\(source.count) bytes)")
      return nil
    }
    length = Int(source[uint32: 0])
    let typeStr = Header.parseType(in: source)
    guard let type = PacketType(rawValue: String(typeStr)) else {
      logger.error("Unable to parse packet of type \(typeStr)")
      return nil
    }
    self.type = type

    // Set the subtype
    if type == .ping {
      self.subtype = .none
      return
    }
    let subtypeStr = Header.parseType(in: source, isSubtype: true)
    guard let subtype = PacketSubtype(rawValue: String(subtypeStr)) else {
      logger.error("Unable to parse packet subtype: \(subtypeStr)")
      return nil
    }
    self.subtype = subtype
  }

  private static func parseType(in src: Data, isSubtype: Bool = false) -> String {
    let rng = isSubtype ? subtypeRange : typeRange
    let raw = src.subdata(in: rng)
    // Need to reverse to account for endianness
    return String(String(data: raw, encoding: .ascii)!.reversed())
  }
}

internal enum PacketType: String {
  case ping = "ping"
  case sync = "sync"
  case async = "asyn"
  case reply = "rply"
}

internal enum PacketSubtype: String {
  // Some packets (ping) don't have a subtype
  case none = "NONE"
  // Clock With Presentation Audio
  case cwpa = "cwpa"
  // Hardware picture description (???)
  case hpd1 = "hpd1"
}

class Ping: ScreenCapturePacket {
  let header: Header
  let data: Data

  var description: String {
    "<ping size:\(data.count)>"
  }

  static let instance: Ping = {
    let data = Data(base64Encoded: "EAAAAGduaXAAAAAAAQAAAA==")!
    return Ping(header: Header(data)!, data: data)!
  }()

  init?(header: Header, data: Data) {
    self.header = header
    self.data = data
  }

  lazy var isValid: Bool = {
    return header.type == .ping && data.count == 16
  }()
}

class AudioClock: ScreenCapturePacket {
  static let packetType: PacketSubtype = .cwpa
  let header: Header
  let data: Data
  let correlationId: String
  let clock: CFTypeID
  private let length = 36
  private let corrIdRange = 20..<28
  private let clockIdx = 28

  lazy var isValid: Bool = {
    return header.type == .sync && header.subtype == .cwpa
  }()

  var description: String {
    "<audio-clock [cwpa] corrId=\(correlationId) clock=\(clock) size:\(data.count)>"
  }

  init?(header: Header, data: Data) {
    self.header = header
    self.data = data
    guard data.count >= length else {
      logger.error("Failed to parse audio clock: Not enough data (expected at least \(36) bytes)")
      return nil
    }
    correlationId = data.subdata(in: corrIdRange).base64EncodedString()
    clock = UInt(data[uint32: clockIdx])
  }
}

class Reply: ScreenCapturePacket {
  var header = Header(length: length, type: .reply)
  var isValid: Bool = true

  var description: String { "<reply corrId=\(correlationId) clock=\(clock)>" }

  private let correlationId: String
  private let clock: CFTypeID
  private static let length = 28

  // Serialized format:
  //
  // -- Header (8 bytes) --
  //  0| Length | 4 bytes | 28
  //  4| Type   | 4 bytes | rply
  // -- Payload --
  //  8| Correlation id | 8 bytes
  // 16| (empty)        | 4 bytes
  // 20| Clock id       | 8 bytes
  lazy var data: Data = {
    var res = Data(capacity: header.length)
    res.copyInto(at: 0, from: header.serialized)
    res.copyInto(at: 8, from: Data(base64Encoded: correlationId)!)
    res.uint64(at: 20, UInt64(clock))
    return res
  }()

  init(correlationId: String, clock: CFTypeID) {
    self.correlationId = correlationId
    self.clock = clock
  }
}

// TODO rename this
class HPD1: ScreenCapturePacket {
  var header: Header
  var data: Data
  var isValid: Bool
  var description: String

  init() {
    data = HPD1.initializeData()
    header = Header(length: Int(data[uint32: 0]), type: .async)
    isValid = true
    description = "fixme"
  }

  private static func initializeData() -> Data {
    var deviceInfo = PacketDict()
    deviceInfo["Valeria"] = .bool(true)
    deviceInfo["HEVCDecoderSupports444"] = .bool(true)
    var dimensions = PacketDict()
    dimensions["Width"] = .number(Number(float64: 1920.0))
    dimensions["Height"] = .number(Number(float64: 1200.0))
    deviceInfo["DisplaySize"] = .dict(dimensions)
    let dictPayload = deviceInfo.serialize()

    var header = Header(length: dictPayload.count + 20, type: .async, subtype: .hpd1).serialized
    header.append(dictPayload)

    return header
  }
}

internal enum PacketParseError: Error {
  case generic(_ msg: String)
  case invalidHeader(_ msg: String)
  case unrecognizedPacketType(_ msg: String)
}

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

typealias PacketDict = [String: DictValue]

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

extension PacketDict {

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

  func serialize() -> Data {
    var result = Data()
    result.append(type.rawValue)
    switch self.type {
    case .int32:
      result.append(type.rawValue)
      result.append(withUnsafeBytes(of: int32Value) { Data($0) })
    case .int64:
      result.append(withUnsafeBytes(of: int64Value) { Data($0) })
    case .float64:
      result.append(withUnsafeBytes(of: float64Value) { Data($0) })
    }
    return result
  }
}
