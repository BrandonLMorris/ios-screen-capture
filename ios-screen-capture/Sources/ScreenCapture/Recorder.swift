import CoreMedia
import Foundation

class Recorder {
  private var device: ScreenCaptureDevice! = nil
  private var sessionActive = false
  private var startTime: UInt64 = 0
  // private let output: MediaReceiver = VideoFile(to: "/tmp/recording.h264")!
  private let output: MediaReceiver = AVAssetReceiver(to: "/tmp/recording.mp4")!
  private let verbose: Bool

  private var audioStartTime: Time! = nil
  private var deviceAudioStart: Time! = nil
  private var localAudioLatest: Time! = nil
  private var deviceAudioLatest: Time! = nil

  private var videoRequest: VideoDataRequest! = nil
  private let closeStreamGroup = DispatchGroup()
  private var audioClockRef: CFTypeID = 0

  init(verbose: Bool = false) {
    self.verbose = verbose
  }

  func start(forDeviceWithId udid: String) throws {
    var screenCaptureDevice = try ScreenCaptureDevice.obtainDevice(withUdid: udid)
    screenCaptureDevice = try screenCaptureDevice.activate()
    logger.info("Activated. We are clear for launch.")

    screenCaptureDevice.initializeRecording(verboseLogging: verbose)
    let packet = try screenCaptureDevice.readPackets().first!
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
    self.output.end()
    guard let device = device else {
      throw RecordingError.recordingUninitialized("Cannot stop() recording that never started!")
    }
    logger.info("Closing stream...")
    try device.sendPacket(packet: CloseStream(clock: audioClockRef))
    try device.sendPacket(packet: CloseStream())
    let closeResult = closeStreamGroup.wait(wallTimeout: .now() + .seconds(3))
    switch closeResult {
    case .timedOut:
      logger.warning("Timed out waiting for the stream to close")
    case .success:
      logger.info("Stream closed successfully")
    }
    sessionActive = false
    device.deactivate()
  }

  private func startMessageLoop() throws {
    // Enter twice since we need releases for audio and video
    closeStreamGroup.enter()
    closeStreamGroup.enter()
    guard let device = device else {
      logger.error("Cannot start message loop without device!")
      return
    }
    sessionActive = true
    while sessionActive {
      guard let packets = try? device.readPackets() else {
        logger.error("Failed to read packet")
        continue
      }
      for packet in packets {
        try handle(packet)
      }
    }
  }

  private func handle(_ packet: ScreenCapturePacket) throws {
    if verbose { logger.debug("\(packet.description)") }
    switch packet {
    case _ as Ping:
      try device.ping()

    case let packet as GoRequest:
      let reply = packet.reply()
      logger.debug("Sending go reply: \(reply.description)")
      try device.sendPacket(packet: reply)

    case let packet as StopRequest:
      let reply = packet.reply()
      logger.debug("Sending stop reply: \(reply.description)")
      try device.sendPacket(packet: reply)

    case let packet as AudioClock:  // cwpa
      let desc = HostDescription()
      logger.debug("Sending host description packet\n\(desc.description)")
      try device.sendPacket(packet: desc)
      logger.debug("Sending stream desc")
      audioClockRef = packet.clock.clock
      try device.sendPacket(packet: StreamDescription(clock: audioClockRef))
      self.audioStartTime = Time.now()
      let reply = Reply(correlationId: packet.clock.correlationId, clock: packet.clock.clock + 1000)
      logger.debug("Sending audio clock reply\n\(reply.description)")
      try device.sendPacket(packet: reply)

    case let packet as AudioFormat:  // afmt
      let reply = packet.reply()
      logger.debug("Sending audio format reply: \(reply.description)")
      try device.sendPacket(packet: packet.reply())

    case let packet as VideoClock:  // cvrp
      self.videoRequest = VideoDataRequest(clock: packet.clockPacket.clock)
      logger.debug("Sending video data request\n\(self.videoRequest.description)")
      try device.sendPacket(packet: videoRequest)
      let reply = packet.reply(withClock: packet.clockPacket.clock + 0x1000AF)
      logger.debug("Sending video clock reply\n\(reply.description)")
      try device.sendPacket(packet: reply)
      logger.debug("Sending video data request\n\(self.videoRequest.description)")
      try device.sendPacket(packet: videoRequest)

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

    case let skewRequest as SkewRequest:  // skew
      logger.debug("Sending skew reply")
      let calculatedSkew = skew(
        localDuration: self.localAudioLatest, deviceDuration: self.deviceAudioLatest)
      let reply = skewRequest.reply(withSkew: calculatedSkew)
      try device.sendPacket(packet: reply)

    case let mediaSample as MediaSample:
      switch mediaSample.mediaType {
      case .video:
        self.output.sendVideo(mediaSample.sample)
        try device.sendPacket(packet: self.videoRequest)
      case .audio:
        self.localAudioLatest = Time.now().since(self.audioStartTime)
        self.deviceAudioLatest = mediaSample.sample.outputPresentation ?? Time.NULL
        if deviceAudioStart == nil {
          self.deviceAudioStart = deviceAudioLatest
        }
      }

    case _ as SetProperty:
      // Nothing to do
      break
    case let packet as AsyncPacket:
      // Nothing to do
      if packet.header.subtype == .release {
        closeStreamGroup.leave()
      }

    default:
      logger.error("Unexpected packet received \(packet.data.base64EncodedString())")
    }
  }
}
