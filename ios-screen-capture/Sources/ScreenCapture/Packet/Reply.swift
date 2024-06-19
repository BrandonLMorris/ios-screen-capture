import Foundation

class Reply: ScreenCapturePacket {
  var header = Header(length: length, type: .reply)
  var description: String { "<reply corrId=\(correlationId) clock=\(clock)>" }

  private let correlationId: String
  private let clock: CFTypeID
  private static let length = 28

  // Serialized format:
  //
  // -- Header (8 bytes) --
  //  0| Length | 4 bytes | 28
  //  4| Type   | 4 bytes | rply
  // -- Payload --
  //  8| Correlation id | 8 bytes
  // 16| (empty)        | 4 bytes
  // 20| Clock id       | 8 bytes
  lazy var data: Data = {
    var res = Data(count: header.length)
    res.copyInto(at: 0, from: header.serialized)
    res.copyInto(at: 8, from: Data(base64Encoded: correlationId)!)
    res.uint64(at: 20, UInt64(clock))
    return res
  }()

  init(correlationId: String, clock: CFTypeID) {
    self.correlationId = correlationId
    self.clock = clock
  }
}
