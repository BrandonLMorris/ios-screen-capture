import CoreMedia
import Foundation
import Testing

@testable import Object

final class FormatDescriptionTests {
  private let videoFixture =
    "rwAAAGNzZGYMAAAAYWlkbWVkaXYQAAAAbWlkdmYEAACECQAADAAAAGNkb2MxY3ZhfwAAAG50eGVYAAAAdnllawoAAABreGRpMQBGAAAAdGNpZD4AAAB2eWVrCgAAAGt4ZGlpACwAAAB2dGFkAWQAM//hABEnZAAzrFaARwEz5p5uBAQEBAEABCjuPLD9+PgAHwAAAHZ5ZWsKAAAAa3hkaTQADQAAAHZydHNILjI2NA=="
  private let audioFixture =
    "RAAAAGNzZGYMAAAAYWlkbW51b3MwAAAAZGJzYQAAAAAAcOdAbWNwbEwAAAAEAAAAAQAAAAQAAAACAAAAEAAAAAAAAAA="

  @Test func videoFromFixture() throws {
    let binary = Data(base64Encoded: videoFixture)!

    #expect(FormatDescription(binary) != nil)
  }

  @Test func audioFromFixture() throws {
    let binary = Data(base64Encoded: audioFixture)!

    #expect(FormatDescription(binary) != nil)
  }

  @Test func formatDescriptionEquality() throws {
    // Equalit of format descriptions depends on the parameter set bytes
    let set1 = "foobar".data(using: .utf8)!
    let set2 = "binbaz".data(using: .utf8)!
    let fd11 = FormatDescription(pps: set1, sps: set1)
    let fd12 = FormatDescription(pps: set1, sps: set2)
    let fd21 = FormatDescription(pps: set2, sps: set1)

    #expect(fd11 == fd11)
    #expect(fd12 != fd21)
    #expect(fd21 == fd21)
  }

  @Test func convertVideoToCMFormatDescription() throws {
    let fd = FormatDescription(Data(base64Encoded: videoFixture)!)!
    let cmfd = fd.toCMFormatDescription()!

    #expect(CMFormatDescriptionGetMediaType(cmfd) == kCMMediaType_Video)
  }
}
