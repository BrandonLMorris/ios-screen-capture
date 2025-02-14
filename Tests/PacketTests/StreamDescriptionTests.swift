import Foundation
import Testing

@testable import Packet

final class StreamDescriptionTests {
  @Test func serializeMatchesFixture() throws {
    let fixture =
      "UQEAAG55c2HwklMUAQAAADFhcGg9AQAAdGNpZDQAAAB2eWVrGwAAAGtydHNCdWZmZXJBaGVhZEludGVydmFsEQAAAHZibW4G5KWbxCCwsj8oAAAAdnllaxEAAABrcnRzZGV2aWNlVUlEDwAAAHZydHNWYWxlcmlhLgAAAHZ5ZWsVAAAAa3J0c1NjcmVlbkxhdGVuY3kRAAAAdmJtbgZ7FK5H4XqkP1cAAAB2eWVrDwAAAGtydHNmb3JtYXRzQAAAAHZ0YWQAAAAAAHDnQG1jcGwMAAAABAAAAAEAAAAEAAAAAgAAABAAAAAAAAAAAAAAAABw50AAAAAAAHDnQCsAAAB2eWVrFgAAAGtydHNFRElEQUMzU3VwcG9ydA0AAAB2Ym1uAwAAAAApAAAAdnllaxIAAABrcnRzZGV2aWNlTmFtZQ8AAAB2cnRzVmFsZXJpYQ=="
    let binary = Data(base64Encoded: fixture)!

    let actual = StreamDescription(clock: /* unused */ 0xdead_beef).data

    let expectedDict = Dictionary(binary.from(20))!
    let actualDict = Dictionary(actual.from(20))!
    #expect(actual.count == binary.count)
    #expect(actualDict.keys == expectedDict.keys)
    for (k, v) in actualDict {
      #expect(v == expectedDict[k]!)
    }
  }
}
