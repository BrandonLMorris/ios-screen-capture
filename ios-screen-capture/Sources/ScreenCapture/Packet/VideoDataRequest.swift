import Foundation

class VideoDataRequest: ScreenCapturePacket {
  var header: Header = Header(length: 20, type: .async, subtype: .videoDataRequest)
  var description: String = "video need request <NEED>"
  private let clock: CFTypeID

  init(clock: CFTypeID) {
    self.clock = clock
    header.payload.uint64(at: 0, UInt64(clock))
  }

  lazy var data: Data = {
    return header.serialized
  }()
}
