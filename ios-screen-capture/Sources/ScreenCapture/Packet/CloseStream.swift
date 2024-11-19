import Foundation

internal class CloseAudioStream: ScreenCapturePacket {
  lazy var header = {
    Header(length: 20, type: .async, subtype: .audioTermination, payload: self.clock)
  }()
  lazy var description: String = {
    """
    [HPA0] Audio stream termination
    """
  }()
  private let clock: CFTypeID

  init(clock: CFTypeID) {
    self.clock = clock
  }

  lazy var data: Data = {
    return header.serialized
  }()
}

internal class CloseVideoStream: ScreenCapturePacket {
  lazy var header = Header(length: 20, type: .async, subtype: .videoTermination)
  lazy var description: String = {
    """
    [HPD0] Video stream termination
    """
  }()

  lazy var data: Data = {
    return header.serialized
  }()
}
