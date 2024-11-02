import Foundation

internal protocol MediaReceiver {
  func sendVideo(_: MediaChunk)
  func end()
}

internal class VideoFile: MediaReceiver {
  private static let startCode = Data([0x00, 0x00, 0x00, 0x01])

  private let outStream: OutputStream
  private let startCodePtr: UnsafeRawPointer = VideoFile.startCode.withUnsafeBytes {
    (ptr: UnsafeRawBufferPointer) -> UnsafeRawPointer in
    ptr.baseAddress!
  }

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
      logger.error("Stream in error state, not writing: \(err.localizedDescription)")
      return
    }

    let startCodeBytesWritten = VideoFile.startCode.withUnsafeBytes { startCodePtr in
      self.outStream.write(startCodePtr.baseAddress!, maxLength: VideoFile.startCode.count)
    }
    if startCodeBytesWritten != VideoFile.startCode.count {
      logger.error("Error writing start code: \(startCodeBytesWritten) bytes written instead of 4")
      logger.error("\(self.outStream.streamError!.localizedDescription)")
    }

    let dataWritten = data.withUnsafeBytes {
      self.outStream.write($0.baseAddress!, maxLength: data.count)
    }
    if dataWritten != data.count {
      logger.error("Error writing data: \(dataWritten) bytes written instead of \(data.count)")
      logger.error("\(self.outStream.streamError!.localizedDescription)")
    }
  }
}
