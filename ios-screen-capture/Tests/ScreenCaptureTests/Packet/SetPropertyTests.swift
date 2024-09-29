import XCTest

final class SetPropertyTests: XCTestCase {
  let fixture1 =
    "QgAAAG55c2GP1sUiDQAAAHBycHMuAAAAdnllax0AAABrcnRzT2JleUVtcHR5TWVkaWFNYXJrZXJzCQAAAHZsdWIB"
  let fixture2 =
    "PQAAAG55c2GP1sUiDQAAAHBycHMpAAAAdnllaxgAAABrcnRzUmVuZGVyRW1wdHlNZWRpYQkAAAB2bHViAA=="

  func testFixture() throws {
    let setProperty = try PacketParser.parse(from: Data(base64Encoded: fixture1)!) as! SetProperty

    XCTAssertEqual(setProperty.propertyKey, "ObeyEmptyMediaMarkers")
    XCTAssertEqual(setProperty.propertyValue, .bool(true))
  }

  func testFixture2() throws {
    let setProperty = try PacketParser.parse(from: Data(base64Encoded: fixture2)!) as! SetProperty

    XCTAssertEqual(setProperty.propertyKey, "RenderEmptyMedia")
    XCTAssertEqual(setProperty.propertyValue, .bool(false))
  }
}
