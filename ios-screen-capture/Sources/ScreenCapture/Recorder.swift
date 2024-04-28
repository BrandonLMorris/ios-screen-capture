import CoreMedia
import Foundation

struct Recorder {
  private var device: ScreenCaptureDevice? = nil
  private var sessionActive = false
  private var correlationId: String = ""
  private var hostClock: CMClock! = nil

  mutating func start(forDeviceWithId udid: String) throws {
    var screenCaptureDevice = try ScreenCaptureDevice.obtainDevice(withUdid: udid)
    screenCaptureDevice = try screenCaptureDevice.activate()
    logger.info("Activated. We are clear for launch.")

    screenCaptureDevice.initializeRecording()
    let packet = try screenCaptureDevice.readPacket()
    guard let ping = packet as? Ping else {
      throw RecordingError.unrecognizedPacket(
        "Fixme: Unexpected first packet; was looking for ping")
    }
    logger.info("We've been pinged! \(ping.data.base64EncodedString())")
    self.device = screenCaptureDevice

    try device!.ping()

    try startMessageLoop()
  }

  mutating func stop() throws {
    sessionActive = false
    guard let device = device else {
      throw RecordingError.recordingUninitialized("Cannot stop() recording that never started!")
    }
    device.deactivate()
  }

  private mutating func startMessageLoop() throws {
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
      switch packet {
      case _ as Ping:
        try device.ping()
      case let packet as AudioClock:
        logger.debug("Received audio clock: \(packet.description)")
        correlationId = packet.correlationId
        hostClock = CMClock.hostTimeClock
        // FIXME before you send this, send hpd1
        let reply = Reply(correlationId: packet.correlationId, clock: packet.clock + 1000)
        try device.sendPacket(packet: reply)
      default:
        logger.error("Unexpected packet received \(packet.data.base64EncodedString())")
      }
    }
  }
}
