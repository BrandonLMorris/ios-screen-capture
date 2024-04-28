import Foundation

class PacketParser {
  // Not instantiable
  private init() {}

  static func parse(from payload: Data) throws -> any ScreenCapturePacket {
    guard let header = Header(payload) else {
      throw PacketParsingError.invalidHeader(
        "Unable to parse header! \(payload.base64EncodedString())")
    }
    switch header.type {
    case .ping:
      let ping = Ping(header: header, data: payload)!
      if case let ping = Ping(header: header, data: payload), ping != nil, !ping!.isValid {
        throw PacketParsingError.generic(
          "Invalid ping packet detected! \(payload.base64EncodedString())")
      }
      return ping
    case .sync:
      logger.info("Received SYNC packet")
      switch header.subtype {
      case .none:
        throw PacketParsingError.generic("sync packet did not have a subtype!")
      case .audioClock:
        let audioClock = AudioClock(header: header, data: payload)
        if let audioClock = audioClock, audioClock.isValid {
          return audioClock
        }
        throw PacketParsingError.generic(
          "Could not parse audio clock: \(String(describing: audioClock))")
      case .hostDescription:
        // Should only be sent
        throw PacketParsingError.generic("Unexpected HPD1 packet")
      }
    case .async:
      throw PacketParsingError.generic("TODO")
    case .reply:
      logger.error("Reply packets are only sent! Not parsing")
      return Ping.instance
    }
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
  case audioClock = "cwpa"
  // Host picture description (???)
  case hostDescription = "hpd1"
}

internal enum PacketParsingError: Error {
  case generic(_ msg: String)
  case invalidHeader(_ msg: String)
  case unrecognizedPacketType(_ msg: String)
}
