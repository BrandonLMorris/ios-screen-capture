import Foundation
import Testing

final class AudioClockTests {
  @Test func parseFromFixture() throws {
    let clock = 4_619_662_560  // Taken from the fixture.
    let fixture = "JAAAAGNueXMBAAAAAAAAAGFwd2PgPVcTAQAAAOB0WhMBAAAA"
    let binary = Data(base64Encoded: fixture)!

    let p = try #require(AudioClock(header: Header(binary)!, data: binary))

    #expect(clock == Int(p.clock.clock))
  }
}
