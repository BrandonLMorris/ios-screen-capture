import Foundation
import Object

public class VideoDataRequest: ScreenCapturePacket {
  public var header: Header = Header(length: 20, type: .async, subtype: .videoDataRequest)
  public lazy var description: String = {
    """
    [NEED] Video data request
        clock=\(String(format: "0x%x", clock))
    """
  }()
  private let clock: CFTypeID

  public init(clock: CFTypeID) {
    self.clock = clock
    header.payload.uint64(at: 0, UInt64(clock))
  }

  public lazy var data: Data = {
    return header.serialized
  }()
}
