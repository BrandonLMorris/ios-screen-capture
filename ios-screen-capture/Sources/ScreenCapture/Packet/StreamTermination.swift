import Foundation

class TerminateVideoStream: ScreenCapturePacket {
  lazy var header: Header = Header(self.data)!
  let description = "[HPD0] Video stream termination"
  private let packetLength = 20

  lazy var data: Data = {
    var res = Data(count: packetLength)
    res.uint32(at: 0, UInt32(packetLength))
    res.copyInto(at: 4, from: PacketType.async.rawValue)
    res.uint64(at: 8, UInt64(1))
    res.copyInto(at: 16, from: PacketSubtype.videoTermination.rawValue)
    return res
  }()
}

class TerminateAudioStream: ScreenCapturePacket {
  lazy var header: Header = Header(self.data)!
  let description = "[HPA0] Audio stream termination"
  private let packetLength = 20
  let clock: UInt64

  init(clock: UInt64) {
    self.clock = clock
  }

  lazy var data: Data = {
    var res = Data(count: packetLength)
    res.uint32(at: 0, UInt32(packetLength))
    res.copyInto(at: 4, from: PacketType.async.rawValue)
    res.uint64(at: 8, self.clock)
    res.copyInto(at: 16, from: PacketSubtype.audioTermination.rawValue)
    return res
  }()
}
