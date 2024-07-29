import XCTest

final class AudioClockTests: XCTestCase {
  func testParseFromFixture() throws {
    let clock = 4_619_662_560  // Taken from the fixture.
    let fixture = "JAAAAGNueXMBAAAAAAAAAGFwd2PgPVcTAQAAAOB0WhMBAAAA"
    let binary = Data(base64Encoded: fixture)!

    let p = AudioClock(header: Header(binary)!, data: binary)!

    XCTAssertEqual(clock, Int(p.clock))
  }
}
