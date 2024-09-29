import Foundation

class TimeRequest: ScreenCapturePacket {
  var header: Header
  var data: Data
  lazy var description: String = {
    """
    [TIME] Clock time request
        corrId: \(correlationId)
        clock: \(String(format: "0x%x", clock))
    """
  }()

  internal let correlationId: String
  internal let clock: CFTypeID

  init?(header: Header, data: Data) {
    self.header = header
    self.data = data

    correlationId = data.subdata(in: 8..<16).base64EncodedString()
    clock = CFTypeID(data[uint64: 20])
  }

  // TODO: Reply with the proper CMTime struct
}
