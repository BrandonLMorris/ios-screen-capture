import Foundation
import Testing

@testable import Packet

final class StreamTerminationTests {
  let terminateVideoFixture = Data(base64Encoded: "FAAAAG55c2EAAAAAAAAAADBkcGg=")!
  let terminateAudioFixture = Data(base64Encoded: "FAAAAG55c2EQ/MUCAQAAADBhcGg=")!
  let fixtureAudioClock = 0x1_02C5_FC10

  @Test func videoTerminationFixture() throws {
    print(CloseStream().data.base64EncodedString())
    #expect(CloseStream().data == terminateVideoFixture)
  }

  @Test func audioTerminationFixture() throws {
    #expect(CloseStream(clock: 0x1_02C5_FC10).data == terminateAudioFixture)
  }
}
