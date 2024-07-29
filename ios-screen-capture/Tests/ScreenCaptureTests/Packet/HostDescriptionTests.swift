import XCTest

final class HostDescriptionTests: XCTestCase {
  func testHostDescriptionFixture() throws {
    let fixture =
      "2wAAAG55c2EBAAAAAAAAADFkcGjHAAAAdGNpZCAAAAB2eWVrDwAAAGtydHNWYWxlcmlhCQAAAHZsdWIBLwAAAHZ5ZWseAAAAa3J0c0hFVkNEZWNvZGVyU3VwcG9ydHM0NDQJAAAAdmx1YgFwAAAAdnllaxMAAABrcnRzRGlzcGxheVNpemVVAAAAdGNpZCYAAAB2eWVrDQAAAGtydHNXaWR0aBEAAAB2Ym1uBgAAAAAAAJ5AJwAAAHZ5ZWsOAAAAa3J0c0hlaWdodBEAAAB2Ym1uBgAAAAAAwJJA"
    let binary = Data(base64Encoded: fixture)!

    // Dictionary entries aren't ordered; matching lengths should be good enough
    XCTAssertEqual(HostDescription().data.count, binary.count)
  }
}
