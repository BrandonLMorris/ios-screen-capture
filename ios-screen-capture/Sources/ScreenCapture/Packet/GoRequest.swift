import Foundation

class GoRequest: ScreenCapturePacket {
  var header: Header
  var data: Data
  lazy var description = """
    [GO]
        corrId=\(correlationId)
    """

  internal let correlationId: String
  internal let clock: CFTypeID

  init?(header: Header, wholePacket: Data) {
    self.header = header
    self.data = wholePacket
    self.clock = CFTypeID(header.payload[uint64: 0])
    self.correlationId = wholePacket.subdata(in: 20..<28).base64EncodedString()
  }

  func reply() -> any ScreenCapturePacket {
    Reply(correlationId: correlationId, clock: nil)
  }
}
