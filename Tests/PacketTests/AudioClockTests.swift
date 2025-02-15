import Foundation
import Testing

@testable import Packet

final class AudioClockTests {
  private let binary = Data(base64Encoded: "JAAAAGNueXMBAAAAAAAAAGFwd2PgPVcTAQAAAOB0WhMBAAAA")!

  @Test func parseFromFixture() throws {
    let clock = 4_619_662_560  // Taken from the fixture.

    let p = try #require(AudioClock(header: Header(binary)!, data: binary))

    #expect(clock == Int(p.clock.clock))
  }

  @Test func parseTooLittleDataFails() throws {
    let tooShort = binary.subdata(in: 0..<8)
    #expect(AudioClock(header: Header(binary)!, data: tooShort) == nil)
  }

  @Test func audioClockDescription() throws {
    let clock = try #require(AudioClock(header: Header(binary)!, data: binary)!)

    #expect(clock.description.lowercased().contains("cwpa"))
    #expect(clock.description.lowercased().contains("audio"))
  }
}
