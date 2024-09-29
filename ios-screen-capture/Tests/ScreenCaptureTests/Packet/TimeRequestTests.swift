import Foundation
import XCTest

final class TimeRequestTests: XCTestCase {
  let fixture = "HAAAAGNueXOAecF8pn8AAGVtaXRQPSITAQAAAA=="
  let replyFixture = "LAAAAHlscHJQPSITAQAAAAAAAADh4ULEYroAAADKmjsBAAAAAAAAAAAAAAA="

  func testFixture() throws {
    let timeRequest = try PacketParser.parse(from: Data(base64Encoded: fixture)!) as! TimeRequest

    // Taken from fixture
    XCTAssertEqual(timeRequest.correlationId, "gHnBfKZ/AAA=")
    XCTAssertEqual(timeRequest.clock, CFTypeID(0x1_1322_3d50))
  }

  func testReplyFixture() throws {
    // TODO
  }
}
