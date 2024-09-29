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
      logger.info("Received async packet (subytpe=\(header.subtype.rawValue))")
      return try parseAsync(header, payload)
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
    case .hostClockRequest:
      guard let hostClockReq = HostClockRequest(header: header, wholePacket: wholePacket) else {
        let encoded = wholePacket.base64EncodedString()
        throw PacketParsingError.generic(
          "Failed to post parse host clock request: \(encoded)")
      }
      return hostClockReq
    case .streamDesciption:
      // Should only be sent
      throw PacketParsingError.generic("Unexpected host description (HPA1) packet")
    case .hostDescription:
      // Should only be sent
      throw PacketParsingError.generic("Unexpected host description (HPD1) packet")
    case .videoDataRequest:
      // Should only be sent
      throw PacketParsingError.generic("Unexpected video request (NEED) packet")
    default:
      throw PacketParsingError.generic("Unknown subtype: \(header.subtype)")
    }
  }

  private static func parseAsync(_ header: Header, _ wholePacket: Data) throws
    -> any ScreenCapturePacket
  {
    switch header.subtype {
    case .setProperty:
      return SetProperty(header: header, wholePacket: wholePacket)!
    default:
      break
    }
    throw PacketParsingError.generic("TODO")
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
  // A single key/value pair for a property of the stream.
  case setProperty = "sprp"
  // Request for a clock reference
  case hostClockRequest = "clok"
  // Zero bytes for type. Note this is different than "none"
  case empty = "\0\0\0\0"
}

internal enum PacketParsingError: Error {
  case generic(_ msg: String)
  case invalidHeader(_ msg: String)
  case unrecognizedPacketType(_ msg: String)
}
