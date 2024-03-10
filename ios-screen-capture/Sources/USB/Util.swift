import Foundation
import os.log

let logger = Logger(subsystem: "dev.brandonmorris.screencapture", category: "tool")

/// Generic for a pointer to a pointer to an object.
///
/// IOKit uses the extra indirection to abstract both creation and memory management.
struct DoublePointer<T> {
  init() { wrapped = nil }
  var wrapped: UnsafeMutablePointer<UnsafeMutablePointer<T>?>!
  var unwrapped: T { wrapped.pointee!.pointee }
}
typealias PluginInterface = DoublePointer<IOCFPlugInInterface>
typealias DeviceInterface = DoublePointer<IOUSBDeviceInterface>
typealias InterfaceInterface = DoublePointer<IOUSBInterfaceInterface>

// Values for USB control transfers
let enableRecordingIndex: UInt16 = 0x02
let disableRecordingIndex: UInt16 = 0x0

let recordingUsbConfiguration = 6

// UUIDs for matching to our USB types.
let kIOUSBDeviceUserClientTypeID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "9dc7b780-9ec0-11d4-a54f-000a27052861" as CFString)
let kIOUSBInterfaceUserClientTypeID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "2d9786c6-9ef3-11D4-ad51-000a27052861" as CFString)
let kIOUSBDeviceInterfaceID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "5c8187d0-9ef3-11D4-8b45-000a27052861" as CFString)
let kIOCFPlugInInterfaceID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "C244E858-109C-11D4-91D4-0050E4C6426F" as CFString)
let kIOUSBInterfaceInterfaceID = CFUUIDCreateFromString(
  kCFAllocatorDefault, "73c97ae8-9ef3-11d4-b1d0-000a27052861" as CFString)

/// Generic iterator for IOKit objects.
internal struct IOIterator: IteratorProtocol, Sequence {
  private var itr: io_iterator_t = 0

  init(itr: io_iterator_t = 0) {
    self.itr = itr
  }

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

func returnString(_ ret: IOReturn) -> String {
  let hex = String(format: "0x%08x", ret)
  // There are a bunch of these, so just list them as we go.
  switch ret {
  case kIOReturnSuccess:
    return "Success!"
  case kIOReturnNotOpen:
    return "Device not open (\(hex))"
  case kIOReturnNoDevice:
    return "No such device (\(hex))"
  default:
    return "Unknown error (\(hex))"
  }
}

/// A find interface request that will match everything.
let anyInterfaceRequest = IOUSBFindInterfaceRequest(
  bInterfaceClass: UInt16(kIOUSBFindInterfaceDontCare),
  bInterfaceSubClass: UInt16(kIOUSBFindInterfaceDontCare),
  bInterfaceProtocol: UInt16(kIOUSBFindInterfaceDontCare),
  bAlternateSetting: UInt16(kIOUSBFindInterfaceDontCare))

enum USBError: Error {
  case generic(_ msg: String)
}
