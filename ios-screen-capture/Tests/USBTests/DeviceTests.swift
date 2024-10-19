import Foundation
import IOKit
import IOKit.usb.IOUSBLib
import Testing

final class DeviceTests {
  @Test func interposingWorks() throws {
    let matching = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary

    // If the interposing isn't working correctly the returned dictionary will
    // have at least one element.
    #expect(CFDictionaryGetCount(matching) == 0)
  }
}
