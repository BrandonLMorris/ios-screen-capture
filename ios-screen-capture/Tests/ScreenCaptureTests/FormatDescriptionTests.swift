import XCTest

final class FormatDescriptionTests: XCTestCase {
  func testFromFixture() throws {
    let fixture =
      "rwAAAGNzZGYMAAAAYWlkbWVkaXYQAAAAbWlkdmYEAACECQAADAAAAGNkb2MxY3ZhfwAAAG50eGVYAAAAdnllawoAAABreGRpMQBGAAAAdGNpZD4AAAB2eWVrCgAAAGt4ZGlpACwAAAB2dGFkAWQAM//hABEnZAAzrFaARwEz5p5uBAQEBAEABCjuPLD9+PgAHwAAAHZ5ZWsKAAAAa3hkaTQADQAAAHZydHNILjI2NA=="
    let binary = Data(base64Encoded: fixture)!

    XCTAssertNotNil(FormatDescription(binary))
  }
}
