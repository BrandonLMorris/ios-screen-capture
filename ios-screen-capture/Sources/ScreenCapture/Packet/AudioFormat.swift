import Foundation

class AudioFormat: ScreenCapturePacket {
  var header: Header
  var data: Data
  fileprivate let correlationId: UInt64

  var description: String {
    """
    [AFMT] Audio format
        corrId=\(correlationId)
    """
  }

  init?(header: Header, data: Data) {
    self.header = header
    self.data = data
    self.correlationId = data[uint64: 20]
  }

  func reply() -> any ScreenCapturePacket {
    AudioFormatReply(to: self)
  }

}

private class AudioFormatReply: ScreenCapturePacket {
  private let originator: AudioFormat
  var header: Header
  var data: Data
  lazy var description: String = {
    """
    [RPLY(AFMT)] Audio format reply
        corrId=\(originator.correlationId)
    """
  }()

  init(to afmt: AudioFormat) {
    self.originator = afmt
    var payload = Dictionary()
    payload["Error"] = .number(Number(int32: 0))
    let serializedDict = payload.serialize()
    header = Header(length: 20 + serializedDict.count, type: .reply, subtype: .none)
    data = header.serialized
    // Append the correlation id
    var corrIdData = Data(count: 8)
    corrIdData.uint64(at:0, originator.correlationId)
    data.append(corrIdData)
    // Append 4b empty space
    data.append(Data(count: 4))
    data.append(serializedDict)
  }
}
