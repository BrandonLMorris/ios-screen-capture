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
      logger.info("Received sync packet (subytpe=\(header.subtype.rawValue))")
      return try parseSync(header, payload)
    case .async:
      throw PacketParsingError.generic("TODO: async packet (subytpe=\(header.subtype.rawValue))")
    case .reply:
      logger.error("Reply packets are only sent! Not parsing")
      return Ping.instance
    }
  }

  private static func parseSync(_ header: Header, _ wholePacket: Data) throws
    -> any ScreenCapturePacket
  {
    switch header.subtype {
    case .none, .empty:
      throw PacketParsingError.generic("sync packet did not have a subtype!")
    case .audioClock:
      let audioClock = AudioClock(header: header, data: wholePacket)
      if let audioClock = audioClock {
        return audioClock
      }
      throw PacketParsingError.generic(
        "Could not parse audio clock: \(String(describing: audioClock))")
    case .audioFormat:
      return AudioFormat(header: header, data: wholePacket)!
    case .videoClock:
      return VideoClock(header: header, data: wholePacket)!
    case .streamDesciption:
      // Should only be sent
      throw PacketParsingError.generic("Unexpected host description (HPA1) packet")
    case .hostDescription:
      // Should only be sent
      throw PacketParsingError.generic("Unexpected host description (HPD1) packet")
    case .videoDataRequest:
      // Should only be sent
      throw PacketParsingError.generic("Unexpected video request (NEED) packet")
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
  // Audio format
  case audioFormat = "afmt"
  // Clock for Video Rate Picture (???)
  case videoClock = "cvrp"
  // Ask the device for more video data
  case videoDataRequest = "need"
  // A dictionary of info about the stream
  case streamDesciption = "hpa1"
  // Zero bytes for type. Note this is different than "none"
  case empty = "\0\0\0\0"
}

internal enum PacketParsingError: Error {
  case generic(_ msg: String)
  case invalidHeader(_ msg: String)
  case unrecognizedPacketType(_ msg: String)
}
