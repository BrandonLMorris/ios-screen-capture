import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os.log

protocol Device {
  var isOpen: Bool { get }
  
  static func getConnected() -> [Self]

  func open() throws
  func close()
}

extension Device {
  // default implementations go here
}

internal func usbInterface() throws -> IOUSBDeviceInterface {
  for service in try IOIterator.usbDevices() {
    var pluginPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>(nil)
    // Score is how close the returned interface matches, but we don't use it.
    var score: sint32 = 0
    var kr = IOCreatePlugInInterfaceForService(
      service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginPtrPtr, &score)
    guard kr == KERN_SUCCESS, let plugin = pluginPtrPtr?.pointee?.pointee else {
      os_log(.error, "Failed to create plugin interface: %d", kr)
      continue
    }

    defer {
      _ = plugin.Release(pluginPtrPtr)
    }

    // Do a little type system dance to work with C's void* while we query the interface.
    var interfacePtrPtr: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?
    kr = withUnsafeMutablePointer(to: &interfacePtrPtr) {
      $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { voidStar in
        plugin.QueryInterface(pluginPtrPtr, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), voidStar)
      }
    }

    guard kr == S_OK, let interface = interfacePtrPtr?.pointee?.pointee else {
      os_log(.error, "Failed querying the interface: %d", kr)
      continue
    }

    os_log(.info, "Obtained device interface")
    return interface
  }
  throw USBError.generic("Failed to create plugin interface for any usb service")
}
