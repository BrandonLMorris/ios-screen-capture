import Foundation

internal class CloseStream: ScreenCapturePacket {
  private let clock: CFTypeID?
  lazy var header = {
    if let clock = clock {
      return Header(length: 20, type: .async, subtype: .audioTermination, payload: clock)
    } else {
      return Header(length: 20, type: .async, subtype: .videoTermination)
    }
  }()

  lazy var description: String = {
    let packetId = if clock == nil { "HPD0" } else { "HPA0" }
    let mediaType = if clock == nil { "Video" } else { "Audio" }
    return """
      [\(packetId)] \(mediaType) stream termination
      """
  }()

  init(clock: CFTypeID? = nil) {
    self.clock = clock
  }

  lazy var data: Data = {
    return header.serialized
  }()
}
