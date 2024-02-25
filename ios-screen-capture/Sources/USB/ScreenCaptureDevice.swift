import Foundation
import IOKit
import IOKit.usb
import os.log

let log = OSLog(subsystem: "dev.brandonmorris.screencapture", category: "tool")

struct ScreenCaptureDevice {
  private let deviceHandle: io_object_t

  private init(deviceHandle: io_object_t) {
    self.deviceHandle = deviceHandle
  }

  static func obtainDevice(withUdid udid: String) throws {
    var deviceFound = false
    // Hyphens are removed in the USB properties
    let udidFixed = udid.replacingOccurrences(of: "-", with: "")

    guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else {
      throw ScreenCaptureError.deviceNotFound("No usb devices found")
    }
    for device in IOIterator.forDevices(matching: matchingDict) {
      defer { IOObjectRelease(device) }
      guard let deviceUdid = getUdid(for: device) else {
        continue
      }
      if deviceUdid == udidFixed {
        // This is the device we want
        os_log(.info, "device acquired: %s", deviceUdid)
        deviceFound = true
      }
    }
    if !deviceFound {
      throw ScreenCaptureError.deviceNotFound("Could not find device with udid \(udid)")
    }
  }

  private static func getUdid(for device: io_object_t) -> String? {
    for regEntry in IOIterator.forRegistryEntries(on: device) {
      defer { IOObjectRelease(regEntry) }
      var deviceProperties: Unmanaged<CFMutableDictionary>?
      IORegistryEntryCreateCFProperties(regEntry, &deviceProperties, kCFAllocatorDefault, 0)
      if let properties = deviceProperties?.takeRetainedValue() as? [String: Any] {
        if let serial = properties["USB Serial Number"] as? String {
          return serial
        }
      }
    }
    _ = IOIterator()
    return nil
  }
}

/// Generic iterator for IOKit objects.
private struct IOIterator: IteratorProtocol, Sequence {
  private var itr: io_iterator_t = 0
  mutating func next() -> io_object_t? {
    guard case let entry = IOIteratorNext(itr), entry != IO_OBJECT_NULL else {
      return nil
    }
    return entry
  }
}

extension IOIterator {
  /// Create an iterator for devices.
  static func forDevices(matching matchingDict: CFDictionary) -> IOIterator {
    var res = IOIterator()
    IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &res.itr)
    return res
  }

  /// Create an iterator for registry entries.
  static func forRegistryEntries(on device: io_object_t) -> IOIterator {
    var res = IOIterator()
    IORegistryEntryCreateIterator(
      device, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &res.itr)
    return res
  }
}

enum ScreenCaptureError: Error {
  case deviceNotFound(_ msg: String)
}
