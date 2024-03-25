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
      }
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
    if subtype == .none {
      var res = Data(capacity: 8)
      res[uint32: 0] = UInt32(8)
      res.copyInto(at: 4, from: type.rawValue.data(using: .ascii)!)
      return res
    }
    // TODO serialize a header with a subtype
    return Data(capacity: 0)
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
  case reply = "rply"
}

internal enum PacketSubtype: String {
  // Some packets (ping) don't have a subtype
  case none = "NONE"
  // Clock With Presentation Audio
  case cwpa = "cwpa"
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
    res[uint64: 20] = UInt64(clock)
    return res
  }()
  

  init(correlationId: String, clock: CFTypeID) {
    self.correlationId = correlationId
    self.clock = clock
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
      return self.withUnsafeBytes { $0.load(fromByteOffset: idx, as: UInt64.self) }
    }
    set(newValue) {
      for i in 0..<8 {
        let shifted = newValue >> (8 * i)
        self[idx + i] = UInt8(shifted & 0xff)
      }
    }
  }

  subscript(uint32 idx: Int = 0) -> UInt32 {
    get {
      return self.withUnsafeBytes { $0.load(fromByteOffset: idx, as: UInt32.self) }
    }
    set(newValue) {
      for i in 0..<4 {
        let shifted = newValue >> (8 * i)
        self[idx + i] = UInt8(shifted & 0xff)
      }
    }
  }

  subscript(uint16 idx: Int = 0) -> UInt16 {
    get {
      return self.withUnsafeBytes { $0.load(fromByteOffset: idx, as: UInt16.self) }
    }
    set(newValue) {
      for i in 0..<2 {
        let shifted = newValue >> (8 * i)
        self[idx + i] = UInt8(shifted & 0xff)
      }
    }
  }

  mutating func copyInto(at startIdx: Int, from toCopy: Data) {
    let rng = startIdx..<startIdx+toCopy.count
    self.replaceSubrange(rng, with: toCopy)
  }
}

