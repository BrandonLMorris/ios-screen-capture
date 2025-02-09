import Foundation

public class ControlPacket: ScreenCapturePacket {
  public var header: Header
  public var data: Data
  public lazy var description = {
    let packetId = header.subtype == .goRequest ? "GO" : "STOP"
    return """
      [\(packetId)]
          corrId=\(correlationId)
      """
  }()

  internal let correlationId: String
  internal let clock: CFTypeID

  public init?(header: Header, wholePacket: Data) {
    self.header = header
    self.data = wholePacket
    self.clock = CFTypeID(header.payload[uint64: 0])
    self.correlationId = wholePacket.subdata(in: 20..<28).base64EncodedString()
  }

  public func reply() -> any ScreenCapturePacket {
    Reply(correlationId: correlationId, clock: nil)
  }
}
