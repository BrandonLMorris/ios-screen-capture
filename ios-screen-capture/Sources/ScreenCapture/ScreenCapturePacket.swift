import Foundation
import os.log

protocol ScreenCapturePacket {
  var header: Header { get }
  var data: Data { get }
  var isValid: Bool { get }
}

struct PacketParser {
  // Not instantiable
  private init() {}

  static func parse(from payload: Data) throws -> ScreenCapturePacket {
    guard let header = Header(payload) else {
      throw PacketParseError.invalidHeader("Unable to parse header!")
    }
    switch header.type {
    case .ping:
      let ping = Ping(header: header, wholePacket: payload)
      guard ping.isValid else {
        throw PacketParseError.generic("Invalid ping packet detected!")
      }
      return ping
    }
  }
}

struct Header: Equatable {
  let length: Int
  let type: PacketType

  private let minLength = 8
  private static let typeRange = 4..<8

  internal init(length: Int, type: PacketType) {
    self.length = length
    self.type = type
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
  }

  private static func parseType(in src: Data) -> String {
    // Need to reverse to account for endianness
    String(String(data: src.subdata(in: typeRange), encoding: .ascii)!.reversed())
  }
}

class Ping: ScreenCapturePacket {
  let header: Header
  let data: Data

  init(header: Header, wholePacket: Data) {
    self.header = header
    data = wholePacket
  }

  lazy var isValid: Bool = {
    return header.type == .ping && data.count == 16
  }()
}

internal enum PacketParseError: Error {
  case generic(_ msg: String)
  case invalidHeader(_ msg: String)
  case unrecognizedPacketType(_ msg: String)
}

extension Data {
  subscript(uint32 idx: Int = 0) -> UInt32 {
    return self.withUnsafeBytes { $0.load(fromByteOffset: idx, as: UInt32.self) }
  }
}

internal enum PacketType: String {
  case ping = "ping"
}
