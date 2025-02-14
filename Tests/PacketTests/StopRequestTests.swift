import Foundation
import Testing

@testable import Packet

final class StopRequestTests {
  private let fixture = "HAAAAGNueXPwX0I1un8AAHBvdHMQSf0CAQAAAA=="
  private let replyFixture = "GAAAAHlscHIQSf0CAQAAAAAAAAAAAAAA"

  @Test func requestFixture() throws {
    let packet = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! ControlPacket

    #expect(packet.header.subtype == .stopRequest)
    #expect(0x7FBA_3542_5FF0 == packet.clock)
    #expect("EEn9AgEAAAA=" == packet.correlationId)
  }

  @Test func responseFixture() throws {
    let packet = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! ControlPacket

    let reply = packet.reply()

    #expect(reply.data.base64EncodedString() == replyFixture)
  }
}
