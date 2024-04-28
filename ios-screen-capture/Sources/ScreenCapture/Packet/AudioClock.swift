import Foundation

class AudioClock: ScreenCapturePacket {
  static let packetType: PacketSubtype = .audioClock
  let header: Header
  let data: Data
  let correlationId: String
  let clock: CFTypeID
  private let length = 36
  private let corrIdRange = 20..<28
  private let clockIdx = 28

  lazy var isValid: Bool = {
    return header.type == .sync && header.subtype == .audioClock
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
