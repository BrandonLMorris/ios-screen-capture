import Foundation

public class HostClockRequest: ScreenCapturePacket {
  public var header: Header
  public var data: Data
  public lazy var description: String = {
    """
    [CLOK] Host clock request
        corrId=\(correlationId)
        clock=\(String(format: "0x%x", clock))
    """
  }()

  internal let correlationId: String
  public let clock: CFTypeID

  init?(header: Header, wholePacket: Data) {
    self.header = header
    self.data = wholePacket
    clock = CFTypeID(header.payload[uint64: 0])
    correlationId = wholePacket.subdata(in: 20..<28).base64EncodedString()
  }

  public func reply(withClock c: CFTypeID) -> Reply {
    Reply(correlationId: correlationId, clock: c)
  }
}
