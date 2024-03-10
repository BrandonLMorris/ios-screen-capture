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
  private(set) var isOpen = false

  private var serviceHandle: io_object_t
  private var activeConfig = -1

  init(_ service: io_object_t) {
    serviceHandle = service
    IOObjectRetain(serviceHandle)
  }

  deinit {
    IOObjectRelease(serviceHandle)
  }

  lazy var deviceInterface: DeviceInterface = {
    return try! getDeviceInterfaceWithRetries()
  }()

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
  func activeConfig(refresh: Bool = false) -> Int {
    if (refresh || activeConfig == -1) {
      activeConfig = Int(deviceInterface.getConfiguration())
    }
    return activeConfig
  }

  var configCount: Int {
    let count = deviceInterface.configCount()
    if count == 0 {
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

    if case let res = deviceInterface.deviceRequest(req), res != kIOReturnSuccess {
      logger.error("Error sending control message! \(returnString(res))")
    }
  }

  private func getDeviceInterfaceWithRetries() throws -> DeviceInterface {
    var deviceInterface: DeviceInterface? = nil
    let maxAttempts = 10
    var attempt = 0
    repeat {
      do {
        deviceInterface = try? getDeviceInterface()
      }
      attempt += 1
      if deviceInterface == nil { Thread.sleep(forTimeInterval: 0.2) }
    } while deviceInterface == nil && attempt < maxAttempts
    guard let toReturn = deviceInterface else {
      throw USBError.generic("Failed to obtain device interface after \(attempt) tries")
    }
    return toReturn
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
    if case let res = deviceInterface.open(), res != kIOReturnSuccess {
      throw USBError.generic("Unable to open device! \(returnString(res))")
    }
    isOpen = true
  }

  func close() {
    if case let res = deviceInterface.close(), res != kIOReturnSuccess {
      logger.error("Error closing the device: \(returnString(res))")
    }
    isOpen = false
  }

  func reset() {
    if case let res = deviceInterface.reset(), res != kIOReturnSuccess {
      logger.error("Error resetting the device: \(returnString(res))")
    }
    isOpen = false
  }

  func hardReset() {
    if case let res = deviceInterface.hardReset(), res != kIOReturnSuccess {
      logger.error("Error resetting the device: \(returnString(res))")
    }
    isOpen = false
    Thread.sleep(forTimeInterval: TimeInterval(0.5))
  }

  func setConfiguration(config: UInt8) {
    if case let cnt = configCount, cnt < config {
      logger.error("Cannot set configuration \(config); only \(cnt) found")
      return
    }
    if case let res = deviceInterface.setConfiguration(config: config), res == kIOReturnSuccess {
      logger.error("Error settting configuration \(config): \(returnString(res))")
      return
    }
    logger.info("Configuration \(config) successfully set")
  }
}

extension PluginInterface {
  private static var _deviceInterface: DeviceInterface? = nil
  fileprivate var deviceInterface: DeviceInterface? {
    if let cached = PluginInterface._deviceInterface {
      return cached
    }
    var deviceInterface = DeviceInterface()
    // Do a little type system dance to work with C's void* while we query the interface.
    let kr = withUnsafeMutablePointer(to: &deviceInterface.wrapped) {
      $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { voidStar in
        unwrapped.QueryInterface(wrapped, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), voidStar)
      }
    }
    guard kr == S_OK else {
      return nil
    }
    // Cache for future references
    PluginInterface._deviceInterface = deviceInterface
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
    guard kr == KERN_SUCCESS else {
      throw USBError.generic("Failed to create plugin interface: \(kr)")
    }
    defer { _ = pluginInterface.unwrapped.Release(pluginInterface.wrapped) }
    // Now use the plugin interface to obtain the device interface.
    guard let deviceInterface = pluginInterface.deviceInterface else {
      throw USBError.generic("Error obtaining the device interface")
    }
    return deviceInterface
  }
}

// Wrappers for IOUSBDeviceInterface functions.
extension DeviceInterface {
  func open() -> IOReturn { unwrapped.USBDeviceOpen(wrapped) }
  func close() -> IOReturn { unwrapped.USBDeviceClose(wrapped) }
  func reset() -> IOReturn { unwrapped.ResetDevice(wrapped) }
  func hardReset() -> IOReturn { unwrapped.USBDeviceReEnumerate(wrapped, 0) }
  func setConfiguration(config: UInt8) -> IOReturn { unwrapped.SetConfiguration(wrapped, config) }
  func deviceRequest(_ request: IOUSBDevRequest) -> IOReturn {
    var req = request // Must be mutable to pass by ref
    return unwrapped.DeviceRequest(wrapped, &req)
  }

  func configCount() -> UInt8 {
    var count = UInt8(0)
    if case let res = unwrapped.GetNumberOfConfigurations(wrapped, &count), res != kIOReturnSuccess {
      // Caller will know something is wrong if there are 0 configurations.
      return UInt8(0)
    }
    return count
  }

  func getConfiguration() -> UInt8 {
    var config: UInt8 = 0
    if case let res = unwrapped.GetConfiguration(wrapped, &config), res != kIOReturnSuccess {
      logger.error("Error getting the current configuration: (\(returnString(res)))")
      return 0
    }
    return config
  }
}
