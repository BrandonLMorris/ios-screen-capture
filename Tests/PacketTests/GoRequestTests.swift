import Foundation
import Testing
@testable import Packet

let requestFixture = "IAAAAGNueXPwX0I1un8AACAhb2cwL9MCAQAAAAEAAAA="
let replyFixture = "GAAAAHlscHIwL9MCAQAAAAAAAAAAAAAA"

let correlationId = "MC/TAgEAAAA="

final class GoRequestTests {
  @Test func requestFixtureParsing() throws {
    let serialized = Data(base64Encoded: requestFixture)!

    let parsed = try! PacketParser.parse(from: serialized) as! ControlPacket

    #expect(parsed.header.subtype == .goRequest)
    #expect(0x7FBA_3542_5FF0 == parsed.clock)
    #expect(correlationId == parsed.correlationId)
  }

  @Test func responseFixtureParsing() throws {
    let serialized = Data(base64Encoded: requestFixture)!
    let parsed = try! PacketParser.parse(from: serialized) as! ControlPacket

    let reply = parsed.reply()

    #expect(reply.data.base64EncodedString() == replyFixture)
    #expect(correlationId == reply.data.subdata(in: 8..<16).base64EncodedString())
  }
}
