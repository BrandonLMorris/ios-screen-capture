import CoreMedia
import Foundation

class Recorder {
  private var device: ScreenCaptureDevice! = nil
  private var sessionActive = false
  private var startTime: UInt64 = 0
  private let output: MediaReceiver = VideoFile(to: "/tmp/recording.h264")!

  func start(forDeviceWithId udid: String) throws {
    var screenCaptureDevice = try ScreenCaptureDevice.obtainDevice(withUdid: udid)
    screenCaptureDevice = try screenCaptureDevice.activate()
    logger.info("Activated. We are clear for launch.")

    screenCaptureDevice.initializeRecording()
    let packet = try screenCaptureDevice.readPacket()
    guard let ping = packet as? Ping else {
      throw RecordingError.unrecognizedPacket(
        "Fixme: Unexpected first packet; was looking for ping. base64: \(packet.data.base64EncodedString())"
      )
    }
    logger.info("We've been pinged! \(ping.data.base64EncodedString())")
    self.device = screenCaptureDevice

    try device.ping()
    try startMessageLoop()
  }

  func stop() throws {
    sessionActive = false
    guard let device = device else {
      throw RecordingError.recordingUninitialized("Cannot stop() recording that never started!")
    }
    device.deactivate()
  }

  private func startMessageLoop() throws {
    guard let device = device else {
      logger.error("Cannot start message loop without device!")
      return
    }
    sessionActive = true
    while sessionActive {
      guard let packet = try? device.readPacket() else {
        logger.error("Failed to read packet")
        return
      }
      try handle(packet)
    }
  }

  private func handle(_ packet: ScreenCapturePacket) throws {
    logger.debug("\(packet.description)")
    switch packet {
    case _ as Ping:
      try device.ping()

    case let packet as GoRequest:
      let reply = packet.reply()
      logger.debug("Sending go reply: \(reply.description)")
      try device.sendPacket(packet: reply)

    case let packet as AudioClock:  // cwpa
      let desc = HostDescription()
      logger.debug("Sending host description packet (2x)\n\(desc.description)")
      try device.sendPacket(packet: desc)
      try device.sendPacket(packet: desc)
      logger.debug("Sending stream desc")
      try device.sendPacket(packet: StreamDescription(clock: packet.clock))
      let reply = Reply(correlationId: packet.correlationId, clock: packet.clock + 1000)
      logger.debug("Sending audio clock reply\n\(reply.description)")
      try device.sendPacket(packet: reply)

    case let packet as AudioFormat:  // afmt
      let reply = packet.reply()
      logger.debug("Sending audio format reply: \(reply.description)")
      try device.sendPacket(packet: packet.reply())

    case let packet as VideoClock:  // cvrp
      let videoDataRequest = VideoDataRequest(clock: packet.clock)
      logger.debug("Sending video data request\n\(videoDataRequest.description)")
      try device.sendPacket(packet: videoDataRequest)
      let reply = packet.reply(withClock: packet.clock + 0x1000AF)
      logger.debug("Sending video clock reply\n\(reply.description)")
      try device.sendPacket(packet: reply)
      logger.debug("Sending video data request\n\(videoDataRequest.description)")
      try device.sendPacket(packet: videoDataRequest)

    case let clockRequest as HostClockRequest:  // clok
      self.startTime = DispatchTime.now().uptimeNanoseconds
      let hostClockId = clockRequest.clock + 0x10000
      let reply = clockRequest.reply(withClock: hostClockId)
      logger.debug("Sending host clock reply\n\(reply.description)")
      try device.sendPacket(packet: reply)

    case let timeRequest as TimeRequest:  // time
      logger.debug("Sending time reply")
      let now = DispatchTime.now().uptimeNanoseconds
      let reply = timeRequest.reply(withTime: Time(nanoseconds: now - startTime))
      try device.sendPacket(packet: reply)

    case let videoSample as VideoSample:  // feed
      let sample = videoSample.sample
      self.output.sendVideo(sample)
      
    case let audioSample as AudioSample: // eat!
      let _ = audioSample.sample
      logger.info("Received audio sample, dropping")

    case _ as SetProperty:
      // Nothing to do
      break

    default:
      logger.error("Unexpected packet received \(packet.data.base64EncodedString())")
    }
  }
}
