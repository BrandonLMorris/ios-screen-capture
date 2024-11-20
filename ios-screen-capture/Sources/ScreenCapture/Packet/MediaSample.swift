import Foundation

class MediaSample: ScreenCapturePacket {
  var header: Header
  var data: Data
  let mediaType: MediaType

  enum MediaType {
    case video, audio
  }

  lazy var description: String = {
    let id = mediaType == .video ? "FEED" : "EAT"
    let type = mediaType == .video ? "Video" : "Audio"
    return """
        [\(id)] \(type) sample
      """
  }()

  internal let sample: MediaChunk

  init?(header: Header, wholePacket: Data, _ mediaType: MediaType) {
    self.header = header
    self.data = wholePacket
    self.mediaType = mediaType

    let chunkType: MediaChunk.ChunkType = if mediaType == .video { .video } else { .audio }
    guard let sample = MediaChunk(data.from(20), mediaType: chunkType) else {
      return nil
    }
    self.sample = sample
  }
}

