import Foundation

class HostClockRequest: ScreenCapturePacket {
  var header: Header
  var data: Data
  lazy var description: String = {
    """
    [CLOK] Host clock request
        corrId=\(correlationId)
        clock=\(String(format: "0x%x", clock))
    """
  }()

  internal let correlationId: String
  internal let clock: CFTypeID

  init?(header: Header, wholePacket: Data) {
    self.header = header
    self.data = wholePacket
    clock = CFTypeID(header.payload[uint64: 0])
    correlationId = wholePacket.subdata(in: 20..<28).base64EncodedString()
  }

  func reply(withClock c: CFTypeID) -> Reply {
    Reply(correlationId: correlationId, clock: c)
  }
}
