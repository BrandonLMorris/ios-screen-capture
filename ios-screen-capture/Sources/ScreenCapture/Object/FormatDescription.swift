import Foundation

/// Metadata about the video/audio, e.g. the h264 PPS/SPS.
///
/// This is roughly analogous to a stripped down CMFormatDescription.
class FormatDescription: Equatable {

  static func == (lhs: FormatDescription, rhs: FormatDescription) -> Bool {
    lhs.pictureParameterSequence == rhs.pictureParameterSequence
      && lhs.sequenceParameterSequence == lhs.sequenceParameterSequence
  }

  private let videoMarker = "ediv"
  private let audioMarker = "nuos"
  // Absolutely no idea where these numbers come from.
  private let parameterSetExtensionIdx = 49
  private let rawParametersIdx = 105

  private(set) var pictureParameterSequence = Data()
  private(set) var sequenceParameterSequence = Data()

  private(set) var audioDetails = AudioDetails.defaultInstance

  init?(_ data: Data) {
    var idx = 0
    guard let formatDescriptionPrefix = Prefix(data.from(idx)) else {
      logger.error("Failed to parse format description prefix")
      return nil
    }
    guard formatDescriptionPrefix.type == .formatDesc else {
      logger.error(
        """
        Unexpected format description prefix type!
          wanted \(DataType.formatDesc.rawValue) but got \(formatDescriptionPrefix.type.rawValue)
        """
      )
      return nil
    }
    idx += Prefix.size

    guard Prefix(data.from(idx)) != nil else {
      logger.error("Failed to parse format description media type prefix")
      return nil
    }
    idx += Prefix.size
    let mediaType = data[strType: idx]
    idx += mediaType.count
    if mediaType == audioMarker {
      logger.info("Continuing format description parsing for audio")
      let descriptorPrefix = Prefix(data.from(idx))!
      guard descriptorPrefix.type == .audioDescriptor else {
        return nil
      }
      if let audioDetails = AudioDetails.parse(from: data.from(idx + Prefix.size)) {
        logger.info("Parsed audio details")
        self.audioDetails = audioDetails
      }
      return
    }

    guard mediaType == videoMarker else {
      logger.warning("Unexpected media type found! (\(mediaType)) Cannot parse format description")
      return nil
    }
    logger.info("Continuing format description parsing for video")

    let (width, height) = getVideoDimensions(data.from(idx))
    idx += 16  // 8b prefix + 2x4b integers
    logger.info("Parsed format description video dimensions (\(width)x\(height))")

    let codec = getVideoCodec(data.from(idx))
    idx += 12  // 8b prefix + 4b codec
    logger.info("Parsed format description video codec \(codec)")

    guard let extensions = Array(data.from(idx)) else {
      logger.error("Error parsing format description extensions array!")
      return nil
    }
    guard let (pps, sps) = getParameterSets(extensions) else {
      logger.error("Error parsing format description parameter sets!")
      return nil
    }
    logger.info("Successfully parsed picture/sequence parameter sets")
    self.pictureParameterSequence = pps
    self.sequenceParameterSequence = sps
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
    // I don't understand why this is the case
    let lastIdx = 8 + pictureSetLength + sequenceSetLength
    let sequenceSet = Data(rawParameterSets.subdata(in: idx..<lastIdx))

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
      logger.error("Not enough data to parse AudioDetails! aborting")
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
