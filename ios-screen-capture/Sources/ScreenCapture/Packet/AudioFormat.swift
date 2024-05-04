import Foundation

class AudioFormat: ScreenCapturePacket {
  var header: Header
  var data: Data
  fileprivate let correlationId: UInt64

  var description: String {
    "<audio-format [afmt] size:\(data.count)>"
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
  var description: String { "<Reply[AFMT] corrId=\(originator.correlationId) >" }

  init(to afmt: AudioFormat) {
    self.originator = afmt
    var payload = Dictionary()
    payload["Error"] = .number(Number(int32: 0))
    let serializedDict = payload.serialize()
    header = Header(length: 20 + serializedDict.count, type: .reply, subtype: .none)
    header.payload.uint64(at: 0, originator.correlationId)
    data = header.serialized
    data.append(serializedDict)
  }
}
