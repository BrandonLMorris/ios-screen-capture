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
    GoReply(from: self)
  }
}

private class GoReply: ScreenCapturePacket {
  let header = Header(length: 24, type: .reply)
  let originator: GoRequest
  lazy var description: String = {
    """
    [RPLY(GO)] Audio format reply
        corrId=\(originator.correlationId)
    """
  }()

  init(from originator: GoRequest) {
    self.originator = originator
  }

  lazy var data: Data = {
    var res = Data(count: header.length)
    res.copyInto(at: 0, from: header.serialized)
    res.copyInto(at: 8, from: Data(base64Encoded: self.originator.correlationId)!)
    return res
  }()
}
