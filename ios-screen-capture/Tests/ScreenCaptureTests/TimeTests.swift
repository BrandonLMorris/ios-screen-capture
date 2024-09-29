import XCTest

final class TimeTests: XCTestCase {
  let fixture = "4eFCxGK6AAAAypo7AQAAAAAAAAAAAAAA"

  func testFixture() throws {
    let time = Time(Data(base64Encoded: fixture)!)!

    XCTAssertEqual(time.value, UInt64(0xBA62C442E1E1))
    XCTAssertEqual(time.scale, UInt32(1000000000))
    XCTAssertEqual(time.flags, UInt32(0x01))
    XCTAssertEqual(time.epoch, UInt64(0))
  }
  
  func testSerializeBackToFixture() throws {
    let time = Time(Data(base64Encoded: fixture)!)!
    
    let serialized = time.serialize()
    
    XCTAssertEqual(serialized.base64EncodedString(), fixture)
  }
}
