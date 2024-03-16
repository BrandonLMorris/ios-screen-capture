import IOKit
import IOKit.usb.IOUSBLib
import XCTest

final class ScreenCaptureDeviceTests: XCTestCase {
  func testInterposing() throws {
    let matching = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
    // If the interposing isn't working correctly the returned dictionary will
    // have at least one element.
    XCTAssertEqual(CFDictionaryGetCount(matching), 0)
  }
}
