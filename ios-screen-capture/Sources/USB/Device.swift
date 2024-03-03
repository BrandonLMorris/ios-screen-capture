import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os.log

protocol Device {
  var isOpen: Bool { get }

  static func getConnected() throws -> [Self]

  func open() throws
  func close()
}

final internal class USBDevice {
  var isOpen = false

  private var serviceHandle: io_object_t
  private var _deviceInterface: IOUSBDeviceInterface?

  init(_ service: io_object_t) {
    serviceHandle = service
    IOObjectRetain(serviceHandle)
  }

  deinit {
    IOObjectRelease(serviceHandle)
  }

  var deviceInterface: IOUSBDeviceInterface? {
    if let iface = _deviceInterface {
      return iface
    } else {
      _deviceInterface = getDeviceInterface()
      return _deviceInterface
    }
  }

}

/// Device protocol implementation.
extension USBDevice: Device {
  static func getConnected() throws -> [USBDevice] {
    var connected = [USBDevice]()
    for service in try IOIterator.usbDevices() {
      connected.append(USBDevice(service))
    }
    return connected
  }

  func open() throws { /* TODO */ }
  func close() { /* TODO */ }
}

private extension PluginInterface {
  var deviceInterface: DeviceInterface? {
    guard let plugin = self.unwrapped else { return nil }
    var deviceInterface = DeviceInterface()
    // Do a little type system dance to work with C's void* while we query the interface.
    let kr = withUnsafeMutablePointer(to: &deviceInterface.wrapped) {
      $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { voidStar in
        plugin.QueryInterface(self.wrapped, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), voidStar)
      }
    }
    guard kr == S_OK, let _ = deviceInterface.unwrapped else {
      return nil
    }
    return deviceInterface
  }

  // TODO We're gonna need an InterfaceInterface in order to transfer data
}

extension USBDevice {
  fileprivate func getDeviceInterface() -> IOUSBDeviceInterface? {
    // First, we have to get the PlugIn interface
    var pluginInterface = PluginInterface()
    var score: sint32 = 0
    let kr = IOCreatePlugInInterfaceForService(
      self.serviceHandle, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface.wrapped, &score)
    guard kr == KERN_SUCCESS, let plugin = pluginInterface.unwrapped else {
      os_log(.error, "Failed to create plugin interface: %d", kr)
      return nil
    }
    defer { _ = plugin.Release(pluginInterface.wrapped) }
    // Now use the plugin interface to obtain the device interface.
    return pluginInterface.deviceInterface?.unwrapped
  }
}

