import Foundation
import Logging
import Packet

private let logger = Logger(label: "ScreenCapturePacket+RecordingPacket")

extension Ping: RecordingPacket {
  func onReceive(_ context: RecordingContext) throws {
    try context.send(packet: Ping.instance)
  }
}

extension ControlPacket: RecordingPacket {
  func onReceive(_ context: RecordingContext) throws {
    let subtype = header.subtype == .goRequest ? "go" : "stop"
    let replyPacket = reply()
    logger.debug("Sending \(subtype) reply", metadata: ["desc": "\(replyPacket.description)"])
    try context.send(packet: replyPacket)
  }
}
