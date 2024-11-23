import Foundation

class ClockPacket {
  let correlationId: String
  let clock: CFTypeID

  private static let minLength = 36
  private static let corrIdRange = 20..<28
  private static let clockIdx = 28

  lazy var description: String = {
    """
        corrId=\(correlationId)
        clock=\(String(format: "0x%x", clock))
    """
  }()

  init?(data: Data) {
    guard data.count >= ClockPacket.minLength else {
      logger.error("Failed to parse clock packet: Not enough data (expected at least \(ClockPacket.minLength) bytes)")
      return nil
    }
    correlationId = data.subdata(in: ClockPacket.corrIdRange).base64EncodedString()
    clock = UInt(data[uint64: ClockPacket.clockIdx])
  }
}

class AudioClock: ScreenCapturePacket {
  var header: Header
  var data: Data
  let clock: ClockPacket

  lazy var description: String = {
    """
    [CWPA] Audio clock
    \(self.clock)
    """
  }()
  
  init?(header: Header, data: Data) {
    self.header = header
    self.data = data
    guard let clock = ClockPacket(data: data) else {
      return nil
    }
    self.clock = clock
  }
}

/// Packet received from the device to establish a clock for video syncing.
class VideoClock: ScreenCapturePacket {
  var header: Header
  var data: Data
  let clockPacket: ClockPacket

  lazy var description: String = {
    """
    [CVRP] Video clock
    \(clockPacket)
    """
  }()

  internal let formatDescription: FormatDescription
  private static let payloadDictIdx = 36

  init?(header: Header, data: Data) {
    self.header = header
    self.data = data
    guard let c = ClockPacket(data: data) else {
      return nil
    }
    clockPacket = c
    guard let payloadDict = Dictionary(data.from(VideoClock.payloadDictIdx)) else {
      // This dictionary contains the PPS/SPS for the video encoding, so we
      // have to have it.
      return nil
    }
    guard let val = payloadDict["FormatDescription"] else { return nil }
    guard case let .formatDescription(fdesc) = val else { return nil }
    self.formatDescription = fdesc
  }

  func reply(withClock c: CFTypeID) -> Reply {
    Reply(correlationId: clockPacket.correlationId, clock: c)
  }
}
