import Foundation
import os.log

let log = OSLog(subsystem: "dev.brandonmorris.screencapture", category: "tool")

let kIOUSBDeviceUserClientTypeID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "9dc7b780-9ec0-11d4-a54f-000a27052861" as CFString)

let kIOUSBDeviceInterfaceID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "5c8187d0-9ef3-11D4-8b45-000a27052861" as CFString)

let kIOCFPlugInInterfaceID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "C244E858-109C-11D4-91D4-0050E4C6426F" as CFString)

/// Generic iterator for IOKit objects.
internal struct IOIterator: IteratorProtocol, Sequence {
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
    IOObjectRetain(res.itr)
    return res
  }

  static func usbDevices() throws -> IOIterator {
    guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else {
      throw USBError.generic("Failed to create matching dictionary for USB services")
    }
    return IOIterator.forDevices(matching: matchingDict)
  }
  
  /// Create an iterator for registry entries.
  static func forRegistryEntries(on device: io_object_t) -> IOIterator {
    var res = IOIterator()
    IORegistryEntryCreateIterator(
      device, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &res.itr)
    return res
  }
}

enum USBError : Error {
  case generic(_ msg: String)
}
