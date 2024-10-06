import XCTest

let requestFixture = "IAAAAGNueXPwX0I1un8AACAhb2cwL9MCAQAAAAEAAAA="
let replyFixture = "GAAAAHlscHIwL9MCAQAAAAAAAAAAAAAA"

let correlationId = "MC/TAgEAAAA="

final class GoRequestTests: XCTestCase {
  func testRequestFixture() throws {
    let serialized = Data(base64Encoded: requestFixture)!

    let parsed = try! PacketParser.parse(from: serialized) as! GoRequest

    XCTAssertEqual(0x7FBA_3542_5FF0, parsed.clock)
    XCTAssertEqual(correlationId, parsed.correlationId)
  }

  func testResponseFixture() throws {
    let serialized = Data(base64Encoded: requestFixture)!
    let parsed = try! PacketParser.parse(from: serialized) as! GoRequest

    let reply = parsed.reply()

    XCTAssertEqual(reply.data.base64EncodedString(), replyFixture)
    XCTAssertEqual(correlationId, reply.data.subdata(in: 8..<16).base64EncodedString())
  }
}
