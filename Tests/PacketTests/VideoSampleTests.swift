import Foundation
import Testing
@testable import Packet

final class VideoSampleTests {
  let fixture = Data(
    base64Encoded:
      "ygAAAG55c2FPI2kfAQAAAGRlZWa2AAAAZnVicyAAAABzdHBv0jLFgQMAAAAAypo7AQAAAAAAAAAAAAAAUAAAAGFpdHMBAAAAAAAAADwAAAABAAAAAAAAAAAAAADSMsWBAwAAAADKmjsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+AAAAdHRhcxsAAAB2eWVrCgAAAGt4ZGkTAAkAAAB2bHViARsAAAB2eWVrCgAAAGt4ZGkVAAkAAAB2bHViAQ=="
  )!

  @Test func fixtureParsing() throws {
    let packet = try PacketParser.parse(from: fixture) as! MediaSample

    let idx19 = try #require(packet.sample.attachments[19])
    guard case let .bool(idx19Value) = idx19 else {
      Issue.record("Expected attachment 19 to be a bool")
      return
    }
    #expect(idx19Value)

    let idx21 = try #require(packet.sample.attachments[21])
    guard case let .bool(idx21Value) = idx21 else {
      Issue.record("Expected attachment 21 to be a bool")
      return
    }
    #expect(idx21Value)
  }
}
