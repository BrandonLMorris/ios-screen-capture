import CoreMedia
import Foundation
import Logging
import Util

private let logger = Logger(label: "FormatDescription")

/// Metadata about the video/audio, e.g. the h264 PPS/SPS.
///
/// This is roughly analogous to a stripped down CMFormatDescription.
public class FormatDescription: Equatable {

  public static func == (lhs: FormatDescription, rhs: FormatDescription) -> Bool {
    lhs.pictureParameterSequence == rhs.pictureParameterSequence
      && lhs.sequenceParameterSequence == lhs.sequenceParameterSequence
  }

  private let videoMarker = "ediv"
  private let audioMarker = "nuos"
  private(set) var mediaMarker: String
  // Absolutely no idea where these numbers come from.
  private let parameterSetExtensionIdx = 49
  private let rawParametersIdx = 105

  public private(set) var pictureParameterSequence = Data()
  public private(set) var sequenceParameterSequence = Data()

  private(set) var audioDetails = AudioDetails.defaultInstance

  init?(_ data: Data) {
    var idx = 0
    guard let formatDescriptionPrefix = Prefix(data.from(idx)) else {
      logger.warning("Failed to parse format description prefix")
      return nil
    }
    guard formatDescriptionPrefix.type == .formatDesc else {
      logger.error(
        "Unexpected format description prefix type!",
        metadata: [
          "expected": "\(DataType.formatDesc.rawValue)",
          "actual": "\(formatDescriptionPrefix.type.rawValue)",
        ]
      )
      return nil
    }
    idx += Prefix.size

    guard Prefix(data.from(idx)) != nil else {
      logger.warning("Failed to parse format description media type prefix")
      return nil
    }
    idx += Prefix.size
    let mediaType = data[strType: idx]
    self.mediaMarker = mediaType
    idx += mediaType.count
    // TODO: Break out audio/video parsing
    if mediaType == audioMarker {
      let descriptorPrefix = Prefix(data.from(idx))!
      guard descriptorPrefix.type == .audioDescriptor else {
        return nil
      }
      if let audioDetails = AudioDetails.parse(from: data.from(idx + Prefix.size)) {
        logger.debug("Parsed audio details")
        self.audioDetails = audioDetails
      }
      return
    }

    guard mediaType == videoMarker else {
      logger.warning(
        "Unexpected media type found! (\(mediaType)) Cannot parse format description")
      return nil
    }

    let (width, height) = getVideoDimensions(data.from(idx))
    idx += 16  // 8b prefix + 2x4b integers
    logger.debug("Parsed format description video dimensions (\(width)x\(height))")

    let _ = getVideoCodec(data.from(idx))
    idx += 12  // 8b prefix + 4b codec

    guard let extensions = Array(data.from(idx)) else {
      logger.warning("Error parsing format description extensions array!")
      return nil
    }
    guard let (pps, sps) = getParameterSets(extensions) else {
      logger.warning("Error parsing format description parameter sets!")
      return nil
    }
    logger.debug("Successfully parsed picture/sequence parameter sets")
    self.pictureParameterSequence = Data(pps)
    self.sequenceParameterSequence = Data(sps)
  }

  // for testing
  init(pps: Data, sps: Data) {
    pictureParameterSequence = pps
    sequenceParameterSequence = sps
    self.mediaMarker = videoMarker
  }

  public func toCMFormatDescription() -> CMFormatDescription? {
    guard self.mediaMarker == videoMarker else {
      // TODO: Support CMFormatDescription for audio
      return nil
    }

    var formatDesc: CMFormatDescription?
    let status = self.sequenceParameterSequence.withUnsafeBytes {
      (sequenceParam: UnsafeRawBufferPointer) in
      self.pictureParameterSequence.withUnsafeBytes { (pictureParam: UnsafeRawBufferPointer) in
        let parameterSets = [
          sequenceParam.baseAddress!.assumingMemoryBound(to: UInt8.self),
          pictureParam.baseAddress!.assumingMemoryBound(to: UInt8.self),
        ]
        let parameterSetSizes = [
          self.sequenceParameterSequence.count, self.pictureParameterSequence.count,
        ]
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
          allocator: kCFAllocatorDefault,
          parameterSetCount: 2,
          parameterSetPointers: parameterSets,
          parameterSetSizes: parameterSetSizes,
          nalUnitHeaderLength: 4,
          formatDescriptionOut: &formatDesc
        )
        return status
      }
    }
    guard status == noErr else {
      logger.warning(
        "Failed to create CMFormatDescription for H264 video! \(status)",
        metadata: ["osstatus": "\(status)"])
      return nil
    }
    return formatDesc
  }

  private func getParameterSets(_ extensions: Array) -> (Data, Data)? {
    // I have no idea where these indices come from
    guard case let .array(parameterSetExtensionArr) = extensions[parameterSetExtensionIdx] else {
      return nil
    }
    guard case let .data(rawParameterSets) = parameterSetExtensionArr[rawParametersIdx] else {
      return nil
    }

    // Picture parameter set
    var idx = 7  // Ignore first 7 bytes for some reason
    let pictureSetLength = Int(rawParameterSets[idx])
    idx += 1
    let pictureSet = Data(rawParameterSets.subdata(in: idx..<(idx + pictureSetLength)))
    idx += pictureSetLength

    // Sequence parameter set
    idx += 2  // Ignore 2 more bytes for some reason
    let sequenceSetLength = Int(rawParameterSets[idx])
    idx += 1
    let sequenceSet = Data(rawParameterSets.subdata(in: idx..<(idx + sequenceSetLength)))

    return (pictureSet, sequenceSet)
  }

  private func getVideoDimensions(_ data: Data) -> (UInt32, UInt32) {
    let width = data[uint32: Prefix.size]
    let height = data[uint32: Prefix.size + 4]
    return (width, height)
  }

  private func getVideoCodec(_ data: Data) -> UInt32 {
    data[uint32: Prefix.size]
  }
}

internal struct AudioDetails {
  let sampleRate: Float64
  let formatId: UInt32
  let formatFlags: UInt32
  let bytesPerPacket: UInt32
  let framesPerPacket: UInt32
  let bytesPerFrame: UInt32
  let channelsPerFrame: UInt32
  let bitsPerChannel: UInt32

  static let defaultInstance = AudioDetails(
    sampleRate: 48000.0,
    formatId: 0x6C70_636D,
    formatFlags: 12,
    bytesPerPacket: 4,
    framesPerPacket: 1,
    bytesPerFrame: 4,
    channelsPerFrame: 2,
    bitsPerChannel: 16
  )

  static func parse(from data: Data) -> AudioDetails? {
    guard data.count >= 36 else {
      logger.warning(
        "Not enough data to parse AudioDetails",
        metadata: [
          "expected": "\(36)",
          "actual": "\(data.count)",
        ])
      return nil
    }
    var idx = 0
    let sampleRate = data[float64: idx]
    idx += 8
    let formatId = data[uint32: idx]
    idx += 4
    let formatFlags = data[uint32: idx]
    idx += 4
    let bytesPerPacket = data[uint32: idx]
    idx += 4
    let framesPerPacket = data[uint32: idx]
    idx += 4
    let bytesPerFrame = data[uint32: idx]
    idx += 4
    let channelsPerFrame = data[uint32: idx]
    idx += 4
    let bitsPerChannel = data[uint32: idx]
    idx += 4

    return AudioDetails(
      sampleRate: sampleRate, formatId: formatId, formatFlags: formatFlags,
      bytesPerPacket: bytesPerPacket, framesPerPacket: framesPerPacket,
      bytesPerFrame: bytesPerFrame, channelsPerFrame: channelsPerFrame,
      bitsPerChannel: bitsPerChannel)
  }
}
