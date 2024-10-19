import Foundation
import Testing

final class StreamTerminationTests {
  let terminateVideoFixture = Data(base64Encoded: "FAAAAG55c2EBAAAAAAAAADBkcGg=")!
  let terminateAudioFixture = Data(base64Encoded: "FAAAAG55c2EQ/MUCAQAAADBhcGg=")!
  let fixtureAudioClock = 0x1_02C5_FC10

  @Test func videoTerminationFixture() throws {
    #expect(TerminateVideoStream().data == terminateVideoFixture)
  }

  @Test func audioTerminationFixture() throws {
    #expect(TerminateAudioStream(clock: 0x1_02C5_FC10).data == terminateAudioFixture)
  }
}
