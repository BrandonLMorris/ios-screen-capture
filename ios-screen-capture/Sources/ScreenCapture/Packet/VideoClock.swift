import Foundation

/// Packet received from the device to establish a clock for video syncing.
///
/// TODO: Consider consolidating this with AudioClock
class VideoClock: ScreenCapturePacket {
  var header: Header
  var data: Data
  lazy var description: String = {
    """
    [CVRP] Video clock
        corrId=\(correlationId)
        clock=\(String(format: "0x%x", clock))
    """
  }()

  private let correlationId: String
  private let correlationIdRange = 20..<28
  // N.b. this clock goes in video requests (i.e. NEED packets).
  let clock: CFTypeID
  private let clockIdx = 28
  internal let formatDescription: FormatDescription

  init?(header: Header, data: Data) {
    self.header = header
    self.data = data
    guard data.count >= (clockIdx + 8) else {
      return nil
    }
    correlationId = data.subdata(in: correlationIdRange).base64EncodedString()
    clock = UInt(data[uint64: clockIdx])
    guard let payloadDict = Dictionary(data.from(clockIdx + 8)) else {
      // This dictionary contains the PPS/SPS for the video encoding, so we
      // have to have it.
      return nil
    }
    guard let val = payloadDict["FormatDescription"] else { return nil }
    guard case let .formatDescription(fdesc) = val else { return nil }
    self.formatDescription = fdesc
  }

  func reply(withClock c: CFTypeID) -> Reply {
    Reply(correlationId: correlationId, clock: c)
  }
}
