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
      writeWithStartCode(formatDesc.pictureParameterSequence)
      writeWithStartCode(formatDesc.sequenceParameterSequence)
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
      let chunkLength = Int(data[uint32: idx])
      idx += 4
      let toWrite = data.subdata(in: idx..<(idx + chunkLength))
      writeWithStartCode(toWrite)
      idx += chunkLength
    }
  }

  private func writeWithStartCode(_ data: Data) {
    data.withUnsafeBytes { dataPtr in
      self.outStream.write(self.startCodePtr, maxLength: 4)
      self.outStream.write(dataPtr.baseAddress!, maxLength: dataPtr.count)
    }
  }
}
