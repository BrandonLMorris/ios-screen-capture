import Foundation

class Reply: ScreenCapturePacket {
  lazy var header = {
    let len = if clock == nil { Reply.lengthNoClock } else { Reply.lengthWithClock }
    return Header(length: len, type: .reply)
  }()
  lazy var description: String = {
    """
    [RPLY] reply (to something)
      corrId=\(correlationId)
      clock=\(String(format: "0x%x", clock ?? 0))
    """
  }()

  let correlationId: String
  let clock: CFTypeID?
  private static let lengthNoClock = 24
  private static let lengthWithClock = 28

  lazy var data: Data = {
    var res = Data(count: header.length)
    res.copyInto(at: 0, from: header.serialized)
    res.copyInto(at: 8, from: Data(base64Encoded: correlationId)!)
    if let clock = clock {
      res.uint64(at: 20, UInt64(clock))
    }
    return res
  }()

  init(correlationId: String, clock: CFTypeID?) {
    self.correlationId = correlationId
    self.clock = clock
  }
}
