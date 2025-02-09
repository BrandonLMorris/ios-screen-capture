import Foundation
import Testing
@testable import Packet

final class SkewRequestTests {
  private let fixture = Data(base64Encoded: "HAAAAGNueXPwX0I1un8AAHdla3Nguf0CAQAAAA==")!
  private let replyFixture = Data(base64Encoded: "HAAAAHlscHJguf0CAQAAAAAAAAAAAAAAAHDnQA==")!
  private let fixtureSkew = 48000.0

  @Test func fixtureParsing() throws {
    let request = try PacketParser.parse(from: fixture) as! SkewRequest

    #expect(0x7FBA_3542_5FF0 == request.clock)
    #expect("YLn9AgEAAAA=" == request.correlationId)
  }

  @Test func replyFixtureParsing() throws {
    let request = try PacketParser.parse(from: fixture) as! SkewRequest

    let reply = request.reply(withSkew: fixtureSkew)

    #expect(reply.data == replyFixture)
  }
}
