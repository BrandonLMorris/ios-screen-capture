import Foundation

class StopRequest: ScreenCapturePacket {
  var header: Header
  var data: Data

  lazy var description: String = """
    [STOP]
        corrId=\(correlationId)
        clock=\(String(format: "0x%x", clock))
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
    StopReply(from: self)
  }
}

private class StopReply: ScreenCapturePacket {
  let header = Header(length: 24, type: .reply)
  let originator: StopRequest
  lazy var description: String = {
    """
    [RPLY(STOP)]
        corrId=\(originator.correlationId)
    """
  }()

  init(from originator: StopRequest) {
    self.originator = originator
  }

  lazy var data: Data = {
    var res = Data(count: header.length)
    res.copyInto(at: 0, from: header.serialized)
    res.copyInto(at: 8, from: Data(base64Encoded: self.originator.correlationId)!)
    return res
  }()
}
