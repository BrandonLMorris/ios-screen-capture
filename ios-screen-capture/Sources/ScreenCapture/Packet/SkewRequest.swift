import Foundation

/// Request from the device for the clock's skew value.
class SkewRequest: ScreenCapturePacket {
  var header: Header
  var data: Data

  internal let correlationId: String
  internal let clock: CFTypeID

  lazy var description = """
      [SKEW]
          corrId=\(correlationId)
          clock=\(String(format: "0x%x", clock))
    """

  init?(header: Header, wholePacket: Data) {
    self.data = wholePacket
    self.header = header
    self.clock = CFTypeID(header.payload[uint64: 0])
    self.correlationId = wholePacket.subdata(in: 20..<28).base64EncodedString()
  }

  func reply(withSkew skew: Float64) -> any ScreenCapturePacket {
    SkewReply(from: self, skew)
  }
}

private class SkewReply: ScreenCapturePacket {
  let header = Header(length: 28, type: .reply)
  let originator: SkewRequest
  let skew: Float64
  lazy var description: String = {
    """
    [RPLY(SKEW)]
        corrId=\(originator.correlationId)
        skew=\(String(format: "%f", self.skew))
    """
  }()

  init(from originator: SkewRequest, _ skew: Float64) {
    self.originator = originator
    self.skew = skew
  }

  lazy var data: Data = {
    var res = Data(count: header.length)
    res.copyInto(at: 0, from: header.serialized)
    res.copyInto(at: 8, from: Data(base64Encoded: self.originator.correlationId)!)
    res.float64(at: 20, skew)
    return res
  }()
}
