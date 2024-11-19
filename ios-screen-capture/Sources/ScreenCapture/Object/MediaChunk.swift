import CoreMedia
import Foundation

/// A hunk of audio or video data.
///
/// Roughly analogous to the Core Media type CMSampleBuffer.
struct MediaChunk {
  private(set) var outputPresentation = Time.NULL  // opts
  private(set) var sampleTiming = [TimingData]()  // stia
  private(set) var sampleData = Data(count: 0)  // sdat, aka nalu
  private(set) var sampleCount = UInt32(0)  // nsmp
  private(set) var sampleSize = [Int]()  // ssiz
  private(set) var formatDescription: FormatDescription? = nil  // fdsc
  private(set) var attachments = Array()  // satt
  private(set) var sampleReady = Array()  // sary

  private var samplesProcessed = 0

  enum ChunkType {
    case video
    case audio
  }
  private(set) var mediaType: ChunkType

  init(_ fdesc: FormatDescription, mediaType: ChunkType = .video) {
    self.formatDescription = fdesc
    self.mediaType = mediaType
  }

  init?(_ data: Data, mediaType: ChunkType = .video) {
    self.mediaType = mediaType
    var idx = 0
    guard let prefix = Prefix(data), prefix.type == .mediaChunk else {
      logger.error("Failed to parse MediaChunk (sbuf). Invalid prefix")
      return nil
    }
    guard prefix.length <= data.count else {
      logger.error(
        "Failed to parse MediaChunk (sbuf). Invalid length (expected \(prefix.length), got \(data.count))"
      )
      return nil
    }
    idx += Prefix.size

    while idx < data.count {
      guard let segmentPrefix = Prefix(data.from(idx)) else {
        logger.error("Error parsing media chunk segment prefix at index \(idx)")
        return nil
      }
      switch segmentPrefix.type {
      case .outputPresentation:
        guard let time = Time(data.from(idx + Prefix.size)) else {
          logger.error("Failed to parse output presentation (opts) in media chunk")
          return nil
        }
        self.outputPresentation = time

      case .sampleTiming:
        self.sampleTiming = MediaChunk.parseSampleTiming(data.from(idx))

      case .sampleData:
        self.sampleData = Data(data.from(idx + Prefix.size))

      case .formatDesc:
        guard let fdesc = FormatDescription(data.from(idx)) else { return nil }
        self.formatDescription = fdesc

      case .sampleCount:
        self.sampleCount = data[uint32: idx + Prefix.size]

      case .sampleSize:
        var sizes = [Int]()
        var subIdx = idx + Prefix.size
        while subIdx < idx + Int(segmentPrefix.length) {
          sizes.append(Int(data[uint32: subIdx]))
          subIdx += 4
        }
        self.sampleSize = sizes

      case .attachments:
        guard let attachments = Array(data.from(idx)) else { return nil }
        self.attachments = attachments

      case .sampleReady:
        guard let readyArray = Array(data.from(idx + Prefix.size)) else { return nil }
        self.sampleReady = readyArray

      case .free:
        // Empty block
        break

      default:
        logger.error(
          "Unexpected media chunk segment prefix type \(data[uint32: idx + 4]) at index \(idx). Skipping..."
        )
      }
      idx += Int(segmentPrefix.length)
    }
  }

  func sampleBuffer(_ pts: CMTime, _ lastPts: CMTime?, fd: CMFormatDescription? = nil)
    -> CMSampleBuffer
  {
    var sampleSize = sampleSize
    var timingInfo = sampleTiming.toCmSampleTimingInfo(pts, lastPts)
    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreate(
      allocator: kCFAllocatorDefault,
      dataBuffer: sampleData.blockBuffer,
      dataReady: true,
      makeDataReadyCallback: nil,
      refcon: nil,
      formatDescription: formatDescription?.toCMFormatDescription() ?? fd,
      sampleCount: CMItemCount(sampleCount),
      sampleTimingEntryCount: timingInfo.count,
      sampleTimingArray: &timingInfo,
      sampleSizeEntryCount: sampleSize.count,
      sampleSizeArray: &sampleSize,
      sampleBufferOut: &sampleBuffer)
    return sampleBuffer!
  }

  private static func parseSampleTiming(_ data: Data) -> [TimingData] {
    guard let prefix = Prefix(data) else { return [] }
    var idx = Prefix.size
    var timings = [TimingData]()
    while idx < prefix.length {
      guard let element = TimingData(data.from(idx)) else { return [] }
      timings.append(element)
      idx += TimingData.size
    }
    return timings
  }
}

internal struct TimingData {
  private(set) var duration: Time
  private(set) var presentation: Time
  private(set) var decode: Time

  internal static let size = Time.size * 3

  init?(_ data: Data) {
    guard data.count >= TimingData.size else { return nil }
    guard let duration = Time(data), let presentation = Time(data.from(Time.size)),
      let decode = Time(data.from(Time.size * 2))
    else { return nil }
    self.duration = duration
    self.presentation = presentation
    self.decode = decode
  }

  func sampleTiming(_ pts: CMTime, _ lastPts: CMTime? = nil) -> CMSampleTimingInfo {
    var dur = CMTime(seconds: (1.0 / 60.0), preferredTimescale: 1_000_000_000)
    if let lastPts = lastPts { dur = CMTimeSubtract(pts, lastPts) }
    return CMSampleTimingInfo(
      duration: dur, presentationTimeStamp: pts,
      decodeTimeStamp: decode.toCMTime())
  }
}

extension Swift.Array where Element == TimingData {
  fileprivate func toCmSampleTimingInfo(_ pts: CMTime, _ lastPts: CMTime?) -> [CMSampleTimingInfo] {
    self.map { $0.sampleTiming(pts, lastPts) }
  }
}

extension Prefix {
  /// Obtain the payload of a segment (the data after the prefix).
  fileprivate func segmentPayload(_ fullData: Data) -> Data {
    fullData.subdata(in: Prefix.size..<Int(self.length))
  }
}
