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
  private var _deviceInterface: DeviceInterface!

  init(_ service: io_object_t) {
    serviceHandle = service
    IOObjectRetain(serviceHandle)
    try? getDeviceInterfaceWithRetries()
  }

  deinit {
    IOObjectRelease(serviceHandle)
  }

  var deviceInterface: DeviceInterface! {
    if let iface = _deviceInterface {
      return iface
    } else {
      try! getDeviceInterfaceWithRetries()
      return _deviceInterface
    }
  }

  func registryEntry(forKey key: String) -> String? {
    for regEntry in IOIterator.forRegistryEntries(on: self.serviceHandle) {
      defer { IOObjectRelease(regEntry) }
      var deviceProperties: Unmanaged<CFMutableDictionary>?
      IORegistryEntryCreateCFProperties(regEntry, &deviceProperties, kCFAllocatorDefault, 0)
      if let properties = deviceProperties?.takeRetainedValue() as? [String: Any] {
        if let serial = properties[key] as? Int {
          return String(serial)
        }
        if let serial = properties[key] as? String {
          return serial
        }
      }
    }
    return nil
  }

  /// Retreive the currently active USB configuration.
  var activeConfig: Int {
    var config: UInt8 = 0
    let kr = deviceInterface.unwrapped!.GetConfiguration(deviceInterface.wrapped, &config)
    if kr != kIOReturnSuccess {
      logger.error("Failed to get the active configuration")
    }
    return Int(config)
  }

  var configCount: Int {
    var count: UInt8 = 0
    let kr = deviceInterface.unwrapped!.GetNumberOfConfigurations(deviceInterface.wrapped, &count)
    if kr != kIOReturnSuccess {
      logger.error("Failed to get the number of configurations")
      return -1
    }
    return Int(count)
  }

  /// Send a control signal to the device.
  func control(index: UInt16) {
    var req = IOUSBDevRequest()
    req.bmRequestType = 0x40  // Host to device, vendor specific
    req.bRequest = 0x52  // Magic byte for managing the recording USB configuration
    req.wIndex = index
    // No actual payload in our request.

    let res = deviceInterface.unwrapped?.DeviceRequest(deviceInterface.wrapped, &req)
    if res != kIOReturnSuccess {
      logger.error("Error sending control message! \(String(describing: res))")
    }
  }

  private func getDeviceInterfaceWithRetries() throws {
    _deviceInterface = nil
    let maxAttempts = 10
    var attempt = 0
    repeat {
      do {
        _deviceInterface = try? getDeviceInterface()
      }
      attempt += 1
      if _deviceInterface == nil { Thread.sleep(forTimeInterval: 0.2) }
    } while _deviceInterface == nil && attempt < maxAttempts
    guard let _ = _deviceInterface else {
      throw USBError.generic("Failed to obtain device interface after \(attempt) tries")
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

  func open() throws {
    let res = deviceInterface.unwrapped?.USBDeviceOpen(deviceInterface.wrapped!)
    guard case let res = res, res == kIOReturnSuccess else {
      throw USBError.generic("Unable to open device! \(String(describing: res))")
    }
    isOpen = true
  }

  func close() {
    let res = deviceInterface.unwrapped?.USBDeviceClose(deviceInterface.wrapped!)
    if let res = res, res != kIOReturnSuccess {
      logger.error("Error closing the device: \(String(describing: res))")
    }
    isOpen = false
  }

  func reset() {
    let res = deviceInterface.unwrapped?.ResetDevice(deviceInterface.wrapped!)
    if let res = res, res != kIOReturnSuccess {
      logger.error("Error resetting the device: \(String(describing: res))")
    }
    isOpen = false
  }

  func hardReset() {
    let res = deviceInterface.unwrapped?.USBDeviceReEnumerate(deviceInterface.wrapped!, 0)
    if let res = res, res != kIOReturnSuccess {
      logger.error("Error resetting the device: \(String(describing: res))")
    }
    isOpen = false
    Thread.sleep(forTimeInterval: TimeInterval(0.5))
  }

  func setConfiguration(config: UInt8) {
    let count = configCount
    guard count >= config else {
      logger.error("Cannot set configuration \(config); only \(count) found")
      return
    }
    let res = deviceInterface.unwrapped?.SetConfiguration(deviceInterface.wrapped!, config)
    guard let res = res, res == kIOReturnSuccess else {
      logger.error("Error settting configuration \(config): \(String(describing: res))")
      return
    }
    logger.info("Configuration \(config) successfully set")
  }
}

extension PluginInterface {
  fileprivate var deviceInterface: DeviceInterface? {
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
  fileprivate func getDeviceInterface() throws -> DeviceInterface {
    // First, we have to get the PlugIn interface
    var pluginInterface = PluginInterface()
    var score: sint32 = 0
    let kr = IOCreatePlugInInterfaceForService(
      self.serviceHandle, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
      &pluginInterface.wrapped, &score)
    guard kr == KERN_SUCCESS, let plugin = pluginInterface.unwrapped else {
      throw USBError.generic("Failed to create plugin interface: \(kr)")
    }
    defer { _ = plugin.Release(pluginInterface.wrapped) }
    // Now use the plugin interface to obtain the device interface.
    guard let deviceInterface = pluginInterface.deviceInterface,
      let _ = pluginInterface.deviceInterface?.unwrapped
    else {
      throw USBError.generic("Error obtaining the device interface")
    }
    return deviceInterface
  }
}
