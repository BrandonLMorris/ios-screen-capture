import Foundation
import Testing

final class VideoDataRequestTests {
  @Test func serializeMatchesFixture() throws {
    let fixture = "FAAAAG55c2GgbMECAQAAAGRlZW4="
    let binary = Data(base64Encoded: fixture)
    // The clock value is the one that matches the fixture.
    let videoDataRequest = VideoDataRequest(clock: 4_341_197_984)

    #expect(binary == videoDataRequest.data)
  }
}
