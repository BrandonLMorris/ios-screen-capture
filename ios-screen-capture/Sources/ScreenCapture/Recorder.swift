import CoreMedia
import Foundation

class Recorder {
  private var device: ScreenCaptureDevice! = nil
  private var sessionActive = false
  private var correlationId: String = ""
  private var hostClock: CMClock! = nil

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
    switch packet {
    case _ as Ping:
      try device.ping()
    case let packet as AudioClock:
      logger.debug("Received audio clock: \(packet.description)")
      correlationId = packet.correlationId
      hostClock = CMClock.hostTimeClock
      logger.debug("Sending host description packet...")
      try device.sendPacket(packet: HostDescription())
      let reply = Reply(correlationId: packet.correlationId, clock: packet.clock + 1000)
      logger.debug("Sending audio clock reply")
      try device.sendPacket(packet: reply)
    case let packet as AudioFormat:
      logger.debug("Received audio format: \(packet.description); replying")
      try device.sendPacket(packet: packet.reply())
    default:
      logger.error("Unexpected packet received \(packet.data.base64EncodedString())")
    }
  }
}
