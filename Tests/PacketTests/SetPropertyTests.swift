import Foundation
import Testing

@testable import Packet

final class SetPropertyTests {
  let fixture1 =
    "QgAAAG55c2GP1sUiDQAAAHBycHMuAAAAdnllax0AAABrcnRzT2JleUVtcHR5TWVkaWFNYXJrZXJzCQAAAHZsdWIB"
  let fixture2 =
    "PQAAAG55c2GP1sUiDQAAAHBycHMpAAAAdnllaxgAAABrcnRzUmVuZGVyRW1wdHlNZWRpYQkAAAB2bHViAA=="

  @Test func fixtureParsing() throws {
    let setProperty = try PacketParser.parse(from: Data(base64Encoded: fixture1)!) as! SetProperty

    #expect(setProperty.propertyKey == "ObeyEmptyMediaMarkers")
    #expect(setProperty.propertyValue == .bool(true))
  }

  @Test func fixtureParsing2() throws {
    let setProperty = try PacketParser.parse(from: Data(base64Encoded: fixture2)!) as! SetProperty

    #expect(setProperty.propertyKey == "RenderEmptyMedia")
    #expect(setProperty.propertyValue == .bool(false))
  }
}
