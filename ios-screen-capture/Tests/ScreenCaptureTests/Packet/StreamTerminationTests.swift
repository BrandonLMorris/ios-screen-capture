import XCTest

final class StreamTerminationTests: XCTestCase {
  let terminateVideoFixture = Data(base64Encoded: "FAAAAG55c2EBAAAAAAAAADBkcGg=")!
  let terminateAudioFixture = Data(base64Encoded: "FAAAAG55c2EQ/MUCAQAAADBhcGg=")!
  let fixtureAudioClock = 0x1_02C5_FC10

  func testVideoTerminationFixture() throws {
    XCTAssertEqual(TerminateVideoStream().data, terminateVideoFixture)
  }

  func testAudioTerminationFixture() throws {
    XCTAssertEqual(TerminateAudioStream(clock: 0x1_02C5_FC10).data, terminateAudioFixture)
  }
}
