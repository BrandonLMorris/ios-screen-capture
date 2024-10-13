import Foundation

class AudioSample: ScreenCapturePacket {
  var header: Header
  var data: Data

  var description = """
    [EAT] Audio sample
  """

  internal let sample: MediaChunk

  init?(header: Header, wholePacket: Data) {
    self.header = header
    self.data = wholePacket
    guard let sample = MediaChunk(data.from(20)) else {
      return nil
    }
    self.sample = sample
  }
}

