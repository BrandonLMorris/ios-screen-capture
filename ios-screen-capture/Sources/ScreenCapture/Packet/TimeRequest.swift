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

  func reply(withTime: Time) -> some ScreenCapturePacket {
    return TimeResponse(to: self, withTime: withTime)
  }
}

/// Response packet for a TimeRequest.
private class TimeResponse: ScreenCapturePacket {
  private let originator: TimeRequest
  var header: Header
  var data: Data
  lazy var description: String = {
    """
    [RPLY(TIME)] Time request reply
        corrId=\(originator.correlationId)
        clock=\(String(format: "0x%x", originator.clock))
    """
  }()

  private let length = 44

  init(to originator: TimeRequest, withTime time: Time) {
    self.originator = originator
    header = Header(length: length, type: .reply, subtype: .none)
    var packetBuilder = header.serialized

    // Append the correlation id
    let corrIdData = Data(base64Encoded: originator.correlationId)!
    packetBuilder.append(corrIdData)

    // Append 4b empty space
    packetBuilder.append(Data(count: 4))

    // Time payload
    packetBuilder.append(time.serialize())

    data = Data(packetBuilder)
  }
}
