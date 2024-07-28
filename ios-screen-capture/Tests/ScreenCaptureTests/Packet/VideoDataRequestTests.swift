import XCTest

final class VideoDataRequestTests: XCTestCase {
  func testSerializeMatchesFixture() throws {
    let fixture = "FAAAAG55c2GgbMECAQAAAGRlZW4="
    let binary = Data(base64Encoded: fixture)
    // The clock value is the one that matches the fixture.
    let videoDataRequest = VideoDataRequest(clock: 4341197984)
    
    XCTAssertEqual(binary, videoDataRequest.data)
  }
}
