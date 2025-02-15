import CoreMedia
import Foundation
import Logging
import Object
import Packet
import Stream
import USB
import Util

private let logger = Logger(label: "Recorder")

public class Recorder {
  private var device: CaptureStream! = nil
  private var context: RecordingContext! = nil
  private var sessionActive = false
  private var startTime: UInt64 = 0
  private let output: MediaReceiver = AVAssetReceiver(to: "/tmp/recording.mp4")!
  private let verbose: Bool

  private var deviceAudioStart: Time! = nil
  private var localAudioLatest: Time! = nil
  private var deviceAudioLatest: Time! = nil

  private let closeStreamGroup = DispatchGroup()

  public init(verbose: Bool = false) {
    self.verbose = verbose
  }

  public func start(forDeviceWithId udid: String) throws {
    var screenCaptureDevice: CaptureStream = try createDeviceCaptureStream(withUdid: udid)
    screenCaptureDevice = try screenCaptureDevice.activate()
    logger.info("Activated. We are clear for launch.", metadata: ["udid": "\(udid)"])

    let packet = try screenCaptureDevice.readPackets().first!
    guard packet as? Ping != nil else {
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

  public func stop() throws {
    self.output.end()
    guard let device = device else {
      logger.warning("Recorder never started; nothing to stop()")
      return
    }
    logger.info("Beginning recorder shutdown...")
    try device.send(packet: CloseStream(clock: context.audioClockRef))
    try device.send(packet: CloseStream())
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
    context = RecordingContext(device, output)
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
    case let recordingPacket as RecordingPacket:
      try recordingPacket.onReceive(&context)
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
      if packet.header.subtype == PacketSubtype.release {
        closeStreamGroup.leave()
      }
    default:
      logger.warning(
        "Unexpected packet received!", metadata: ["base64": "\(packet.data.base64EncodedString())"])
    }
  }

  // MARK: Host clock (clok) request

  private func handle(_ clockRequest: HostClockRequest) throws {
    self.startTime = DispatchTime.now().uptimeNanoseconds
    let hostClockId = clockRequest.clock + 0x10000
    let reply = clockRequest.reply(withClock: hostClockId)
    logger.debug("Sending host clock reply", metadata: ["desc": "\(reply.description)"])
    try device.send(packet: reply)
  }

  // MARK: Time request (time)

  private func handle(_ timeRequest: TimeRequest) throws {
    logger.debug("Sending time reply")
    let now = DispatchTime.now().uptimeNanoseconds
    let reply = timeRequest.reply(withTime: Time(nanoseconds: now - startTime))
    try device.send(packet: reply)
  }

  // MARK: Skew request (skew)

  private func handle(_ skewRequest: SkewRequest) throws {
    logger.debug("Sending skew reply")
    let calculatedSkew = skew(
      localDuration: self.localAudioLatest, deviceDuration: self.deviceAudioLatest)
    let reply = skewRequest.reply(withSkew: calculatedSkew)
    try device.send(packet: reply)
  }

  // MARK: Media sample (feed, eat)

  private func handle(_ mediaSample: MediaSample) throws {
    switch mediaSample.mediaType {
    case .video:
      self.output.sendVideo(mediaSample.sample)
      try device.send(packet: context.videoRequest)
    case .audio:
      self.localAudioLatest = Time.now().since(context.audioStartTime)
      self.deviceAudioLatest = mediaSample.sample.outputPresentation ?? Time.NULL
      if deviceAudioStart == nil {
        self.deviceAudioStart = deviceAudioLatest
      }
    }
  }
}

protocol RecordingPacket {
  func onReceive(_ context: inout RecordingContext) throws
}

struct RecordingContext {
  private let device: CaptureStream
  private let mediaReceiver: MediaReceiver

  public var audioClockRef: CFTypeID = 0
  public var audioStartTime: Time = Time.NULL!
  public var videoRequest: VideoDataRequest! = nil

  internal init(_ device: CaptureStream, _ mediaReceiver: MediaReceiver) {
    self.device = device
    self.mediaReceiver = mediaReceiver
  }

  func send(packet: any ScreenCapturePacket) throws {
    try device.send(packet: packet)
  }

  func recordVideoSample(_ mediaSample: MediaSample) throws {
    mediaReceiver.sendVideo(mediaSample.sample)
  }
}

enum RecordingError: Error {
  case unrecognizedPacket(_ msg: String)
  case recordingUninitialized(_ msg: String)
}
