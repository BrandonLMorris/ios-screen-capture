import CoreMedia
import Foundation
import Logging

private let logger = Logger(label: "Recorder")

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
    logger.info("Activated. We are clear for launch.", metadata: ["udid": "\(udid)"])

    screenCaptureDevice.initializeRecording(verboseLogging: verbose)
    let packet = try screenCaptureDevice.readPackets().first!
    guard let _ = packet as? Ping else {
      // TODO: There should be a way to recover or restart the stream
      logger.error(
        "Non-ping packet received", metadata: ["base64": "\(packet.data.base64EncodedString())"])
      throw RecordingError.unrecognizedPacket("Unexpected first packet; was looking for ping")
    }
    logger.debug("Ping packet received; continuing init", metadata: ["udid": "\(udid)"])
    self.device = screenCaptureDevice

    try device.ping()
    try startMessageLoop()
  }

  func stop() throws {
    self.output.end()
    guard let device = device else {
      logger.warning("Recorder never started; nothing to stop()")
      return
    }
    logger.info("Beginning recorder shutdown...")
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
      do {
        try device.readPackets().forEach { try handle($0) }
      } catch {
        logger.warning("Failed to read one or more packets: \(error.localizedDescription)")
        continue
      }
    }
  }

  private func handle(_ packet: ScreenCapturePacket) throws {
    logger.trace("Handling \(type(of: packet)) packet", metadata: ["desc": "\(packet)"])
    switch packet {
    case _ as Ping:
      try device.ping()
    case let controlPacket as ControlPacket:
      try handle(controlPacket)
    case let audioClockPacket as AudioClock:
      try handle(audioClockPacket)
    case let audioFormatPacket as AudioFormat:
      let audioFormatReply = audioFormatPacket.reply()
      logger.debug(
        "Sending audio format reply", metadata: ["desc": "\(audioFormatReply.description)"])
      try device.sendPacket(packet: audioFormatPacket.reply())
    case let videoClockPacket as VideoClock:
      try handle(videoClockPacket)
    case let clockRequest as HostClockRequest:
      try handle(clockRequest)
    case let timeRequest as TimeRequest:
      try handle(timeRequest)
    case let skewRequest as SkewRequest:
      try handle(skewRequest)
    case let mediaSample as MediaSample:
      try handle(mediaSample)
    case _ as SetProperty:
      // Nothing to do
      break
    case let packet as AsyncPacket:
      if packet.header.subtype == .release {
        closeStreamGroup.leave()
      }
    default:
      logger.warning(
        "Unexpected packet received!", metadata: ["base64": "\(packet.data.base64EncodedString())"])
    }
  }

  // MARK: Control (go/stop) packet handling

  private func handle(_ controlPacket: ControlPacket) throws {
    if controlPacket.header.subtype == .goRequest {
      let goReply = controlPacket.reply()
      logger.debug("Sending go reply", metadata: ["desc": "\(goReply.description)"])
      try device.sendPacket(packet: goReply)
    }
    if controlPacket.header.subtype == .stopRequest {
      let stopReply = controlPacket.reply()
      logger.debug("Sending stop reply", metadata: ["desc": "\(stopReply.description)"])
      try device.sendPacket(packet: stopReply)
    }
  }

  // MARK: Audio clock (cwpa) packet handling

  private func handle(_ audioClockPacket: AudioClock) throws {
    let desc = HostDescription()
    logger.debug("Sending host description packet", metadata: ["desc": "\(desc.description)"])
    try device.sendPacket(packet: desc)
    logger.debug("Sending stream desc")
    audioClockRef = audioClockPacket.clock.clock
    try device.sendPacket(packet: StreamDescription(clock: audioClockRef))
    self.audioStartTime = Time.now()
    let audioClockReply = Reply(
      correlationId: audioClockPacket.clock.correlationId,
      clock: audioClockPacket.clock.clock + 1000)
    logger.debug("Sending audio clock reply", metadata: ["desc": "\(audioClockReply.description)"])
    try device.sendPacket(packet: audioClockReply)
  }

  // MARK: Video clock (cvrp) packet handling

  private func handle(_ videoClockPacket: VideoClock) throws {
    self.videoRequest = VideoDataRequest(clock: videoClockPacket.clockPacket.clock)
    logger.debug(
      "Sending video data request", metadata: ["desc": "\(self.videoRequest.description)"])
    try device.sendPacket(packet: videoRequest)
    let videoClockReply = videoClockPacket.reply(
      withClock: videoClockPacket.clockPacket.clock + 0x1000AF)
    logger.debug("Sending video clock reply", metadata: ["desc": "\(videoClockReply.description)"])
    try device.sendPacket(packet: videoClockReply)
    logger.debug(
      "Sending video data request", metadata: ["desc": "\(self.videoRequest.description)"])
    try device.sendPacket(packet: videoRequest)
  }

  // MARK: Host clock (clok) request

  private func handle(_ clockRequest: HostClockRequest) throws {
    self.startTime = DispatchTime.now().uptimeNanoseconds
    let hostClockId = clockRequest.clock + 0x10000
    let reply = clockRequest.reply(withClock: hostClockId)
    logger.debug("Sending host clock reply", metadata: ["desc": "\(reply.description)"])
    try device.sendPacket(packet: reply)
  }

  // MARK: Time request (time)

  private func handle(_ timeRequest: TimeRequest) throws {
    logger.debug("Sending time reply")
    let now = DispatchTime.now().uptimeNanoseconds
    let reply = timeRequest.reply(withTime: Time(nanoseconds: now - startTime))
    try device.sendPacket(packet: reply)
  }

  // MARK: Skew request (skew)

  private func handle(_ skewRequest: SkewRequest) throws {
    logger.debug("Sending skew reply")
    let calculatedSkew = skew(
      localDuration: self.localAudioLatest, deviceDuration: self.deviceAudioLatest)
    let reply = skewRequest.reply(withSkew: calculatedSkew)
    try device.sendPacket(packet: reply)
  }

  // MARK: Media sample (feed, eat)

  private func handle(_ mediaSample: MediaSample) throws {
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
  }
}
