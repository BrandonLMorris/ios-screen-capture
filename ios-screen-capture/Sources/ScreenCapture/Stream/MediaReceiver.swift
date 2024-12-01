import AVFoundation
import CoreMedia
import Foundation
import Logging

internal protocol MediaReceiver {
  func sendVideo(_: MediaChunk)
  func end()
}

internal class VideoFile: MediaReceiver {
  private static let startCode = Data([0x00, 0x00, 0x00, 0x01])
  private let outStream: OutputStream
  private let logger = Logger(label: "VideoFile")

  init?(to filePath: String) {
    guard let outStream = OutputStream(toFileAtPath: filePath, append: false) else {
      logger.error("Failed to create output stream to \(filePath)")
      return nil
    }
    self.outStream = outStream
    self.outStream.open()
  }

  func sendVideo(_ chunk: MediaChunk) {
    if let formatDesc = chunk.formatDescription {
      writeWithStartCode(formatDesc.sequenceParameterSequence)
      writeWithStartCode(formatDesc.pictureParameterSequence)
    }
    if chunk.sampleData.count > 0 {
      write(chunk.sampleData)
    }
  }

  func end() {
    outStream.close()
  }

  private func write(_ data: Data) {
    var idx = 0
    while idx < data.count {
      let chunkLength = Int(data[uint32: idx].bigEndian)
      idx += 4
      let toWrite = data.subdata(in: idx..<min(idx + chunkLength, data.count))
      writeWithStartCode(toWrite)
      idx += chunkLength
    }
  }

  private func writeWithStartCode(_ data: Data) {
    if let err = self.outStream.streamError {
      logger.warning("Stream in error state, not writing: \(err.localizedDescription)")
      return
    }

    let startCodeBytesWritten = VideoFile.startCode.withUnsafeBytes { startCodePtr in
      self.outStream.write(startCodePtr.baseAddress!, maxLength: VideoFile.startCode.count)
    }
    if startCodeBytesWritten != VideoFile.startCode.count {
      logger.warning(
        "Error writing start code: should have written 4 bytes",
        metadata: [
          "bytesWritten": "\(startCodeBytesWritten)",
          "errorDesc": "\(self.outStream.streamError!.localizedDescription)",
        ])
    }

    let dataWritten = data.withUnsafeBytes {
      self.outStream.write($0.baseAddress!, maxLength: data.count)
    }
    if dataWritten != data.count {
      logger.warning(
        "Incorrect ammount of data written",
        metadata: [
          "bytesWritten": "\(dataWritten)",
          "bytesToWrite": "\(data.count)",
          "errorDesc": "\(self.outStream.streamError!.localizedDescription)",
        ])
    }
  }
}

internal class AVAssetReceiver: MediaReceiver {
  private let assetWriter: AVAssetWriter
  private var assetWriterInput: AVAssetWriterInput? = nil
  private var formatDescription: CMFormatDescription!
  private var startedInput: Bool = false
  private var lastPts: CMTime! = nil
  private var presentationTimestamp: CMTime! = nil
  private var bufferCount = 0
  private lazy var logger = Logger(label: "AVAssetReceiver")

  init?(to filePath: String) {
    AVAssetReceiver.deleteIfExists(filePath)
    guard let assetWriter = try? AVAssetWriter(outputURL: URL(filePath: filePath), fileType: .mp4)
    else {
      return nil
    }
    self.assetWriter = assetWriter
  }

  func sendVideo(_ chunk: MediaChunk) {
    if self.assetWriterInput == nil {
      initializeAssetWriterInput(chunk)
    }
    self.lastPts = self.presentationTimestamp
    self.presentationTimestamp = CMClock.hostTimeClock.time
    if !startedInput {
      self.assetWriter.startSession(atSourceTime: .zero)
      startedInput = true
    }
    guard self.assetWriter.status == .writing else {
      logger.warning("Unexpected asset writer status: \(self.assetWriter.status.rawValue)")
      return
    }
    guard let assetWriterInput = self.assetWriterInput else { return }

    let sampleBuffer = chunk.sampleBuffer(bufferCount, fd: self.formatDescription)
    guard CMSampleBufferIsValid(sampleBuffer) else {
      logger.warning("Sample buffer is invalid! dropping")
      return
    }
    guard startedInput else {
      logger.warning("Asset writer session has not started; dropping sample buffer")
      return
    }
    guard assetWriterInput.isReadyForMoreMediaData else {
      logger.warning("Asset writer input is not ready for more media data; dropping buffer")
      return
    }
    guard assetWriterInput.append(sampleBuffer) else {
      logger.warning("Failed to append sample buffer!",
        metadata: [
          "osstatus": "\(self.assetWriter.status.rawValue)",
          "error": "\(String(describing: self.assetWriter.error))"
        ]
      )
      return
    }
    bufferCount += 1
  }

  func end() {
    assetWriterInput?.markAsFinished()
    let writer = assetWriter
    writer.endSession(
      atSourceTime: CMTime(value: CMTimeValue(bufferCount * 1000), timescale: 60_000))

    writer.finishWriting {}
  }

  private func initializeAssetWriterInput(_ chunk: MediaChunk) {
    logger.info("Initializing asset writer input")
    guard let fd = chunk.formatDescription else {
      logger.warning("Media chunk lacks format description; skipping")
      return
    }
    guard let cmFormatDescription = fd.toCMFormatDescription() else {
      logger.warning("Failed to construct CMFormatDescription; skipping")
      return
    }
    self.formatDescription = cmFormatDescription

    let videoInput = AVAssetWriterInput(
      mediaType: .video, outputSettings: nil,
      sourceFormatHint: cmFormatDescription)
    videoInput.expectsMediaDataInRealTime = true
    videoInput.mediaTimeScale = 60_000
    guard self.assetWriter.canAdd(videoInput) else {
      logger.error("AVAssetWriter cannot add input!")
      return
    }
    self.assetWriter.add(videoInput)
    guard self.assetWriter.startWriting() else {
      logger.error("Failed to start writing AVAssetWriter!",
        metadata: [
          "status": "\(self.assetWriter.status.rawValue)",
          "error": "\(self.assetWriter.error?.localizedDescription ?? "none")"
        ]
      )
      return
    }
    self.assetWriterInput = videoInput
    logger.info("Successfully initialized asset writer video input")
  }

  private static func deleteIfExists(_ file: String) {
    let fm = FileManager.default
    guard fm.fileExists(atPath: file) else { return }
    do {
      try fm.removeItem(atPath: file)
    } catch {
      Logger(label: "AVAssetReceiver").error("Failed to delete file at \(file): \(error)")
    }
  }
}
