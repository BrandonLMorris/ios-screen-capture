import Foundation
import Logging
import Object
import Packet

private let logger = Logger(label: "ScreenCapturePacket+RecordingPacket")

extension Ping: RecordingPacket {
  func onReceive(_ context: inout RecordingContext) throws {
    try context.send(packet: Ping.instance)
  }
}

extension ControlPacket: RecordingPacket {
  func onReceive(_ context: inout RecordingContext) throws {
    let subtype = header.subtype == .goRequest ? "go" : "stop"
    let replyPacket = reply()
    logger.debug("Sending \(subtype) reply", metadata: ["desc": "\(replyPacket.description)"])
    try context.send(packet: replyPacket)
  }
}

extension AudioClock: RecordingPacket {
  func onReceive(_ context: inout RecordingContext) throws {
    let desc = HostDescription()
    logger.debug("Sending host description packet", metadata: ["desc": "\(desc.description)"])
    try context.send(packet: desc)
    logger.debug("Sending stream desc")
    context.audioClockRef = clock.clock
    try context.send(packet: StreamDescription(clock: context.audioClockRef))
    context.audioStartTime = Time.now()
    let audioClockReply = Reply(
      correlationId: clock.correlationId,
      clock: clock.clock + 1000)
    logger.debug("Sending audio clock reply", metadata: ["desc": "\(audioClockReply.description)"])
    try context.send(packet: audioClockReply)
  }
}

extension AudioFormat: RecordingPacket {
  func onReceive(_ context: inout RecordingContext) throws {
    let audioFormatReply = reply()
    logger.debug(
      "Sending audio format reply", metadata: ["desc": "\(audioFormatReply.description)"])
    try context.send(packet: audioFormatReply)
  }
}

extension VideoClock: RecordingPacket {
  func onReceive(_ context: inout RecordingContext) throws {
    context.videoRequest = VideoDataRequest(clock: clockPacket.clock)
    logger.debug(
      "Sending video data request", metadata: ["desc": "\(description)"])
    try context.send(packet: context.videoRequest)
    let videoClockReply = reply(withClock: clockPacket.clock + 0x1000AF)
    logger.debug("Sending video clock reply", metadata: ["desc": "\(videoClockReply.description)"])
    try context.send(packet: videoClockReply)
    logger.debug(
      "Sending video data request", metadata: ["desc": "\(context.videoRequest.description)"])
    try context.send(packet: context.videoRequest)

  }
}
