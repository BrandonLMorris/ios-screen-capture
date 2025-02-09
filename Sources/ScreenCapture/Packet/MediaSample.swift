import Foundation
import Object

public class MediaSample: ScreenCapturePacket {
  public var header: Header
  public var data: Data
  public let mediaType: MediaType
  public let sample: MediaChunk

  public enum MediaType {
    case video, audio
  }

  public lazy var description: String = {
    let id = mediaType == .video ? "FEED" : "EAT"
    let type = mediaType == .video ? "Video" : "Audio"
    return """
        [\(id)] \(type) sample
      """
  }()

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
