import XCTest

final class VideoSampleTests: XCTestCase {
  let fixture = Data(base64Encoded: "ygAAAG55c2FPI2kfAQAAAGRlZWa2AAAAZnVicyAAAABzdHBv0jLFgQMAAAAAypo7AQAAAAAAAAAAAAAAUAAAAGFpdHMBAAAAAAAAADwAAAABAAAAAAAAAAAAAADSMsWBAwAAAADKmjsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+AAAAdHRhcxsAAAB2eWVrCgAAAGt4ZGkTAAkAAAB2bHViARsAAAB2eWVrCgAAAGt4ZGkVAAkAAAB2bHViAQ==")!

  func testFixture() throws {
    let packet = try PacketParser.parse(from: fixture) as! VideoSample

    let idx19 = try XCTUnwrap(packet.sample.attachments[19])
    guard case let .bool(idx19Value) = idx19 else {
      XCTFail("Expected attachment 19 to be a bool")
      return
    }
    XCTAssertTrue(idx19Value)

    let idx21 = try XCTUnwrap(packet.sample.attachments[21])
    guard case let .bool(idx21Value) = idx21 else {
      XCTFail("Expected attachment 21 to be a bool")
      return
    }
    XCTAssertTrue(idx21Value)
  }
}
