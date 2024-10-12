import XCTest

final class SkewRequestTests: XCTestCase {
  private let fixture = Data(base64Encoded: "HAAAAGNueXPwX0I1un8AAHdla3Nguf0CAQAAAA==")!
  private let replyFixture = Data(base64Encoded: "HAAAAHlscHJguf0CAQAAAAAAAAAAAAAAAHDnQA==")!
  private let fixtureSkew = 48000.0

  func testFixture() throws {
    let request = try PacketParser.parse(from: fixture) as! SkewRequest

    XCTAssertEqual(0x7FBA_3542_5FF0, request.clock)
    XCTAssertEqual("YLn9AgEAAAA=", request.correlationId)
  }

  func testReplyFixture() throws {
    let request = try PacketParser.parse(from: fixture) as! SkewRequest

    let reply = request.reply(withSkew: fixtureSkew)

    XCTAssertEqual(reply.data, replyFixture)
  }
}
