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
    try! getDeviceInterfaceWithRetries()
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

  func getInterface(withSubclass subclass: UInt8, withAlt alt: UInt8) -> InterfaceInterface? {
    for ifaceHandle in deviceInterface.interfaceIterator(req: anyInterfaceRequest) {
      let iface = try! getInterfaceInterface(for: ifaceHandle)
      if iface.subclass == subclass && iface.alt == alt {
        return iface
      }
    }
    return nil
  }

  /// Retreive the currently active USB configuration.
  func activeConfig(refresh: Bool = false) -> Int {
    if refresh || activeConfig == -1 {
      activeConfig = Int(deviceInterface.configuration)
    }
    return activeConfig
  }

  var configCount: Int {
    let count = deviceInterface.configCount
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

  fileprivate var deviceInterface: DeviceInterface? {
    var deviceInterface = DeviceInterface()
    // Do a little type system dance to work with C's void* while we query the interface.
    let kr = withUnsafeMutablePointer(to: &deviceInterface.wrapped) {
      $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { voidStar in
        unwrapped.QueryInterface(wrapped, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), voidStar)
      }
    }
    guard kr == S_OK else {
      let code = String(format: "0x%08x", kr)
      logger.error("Error querying the device interface: \(code)")
      return nil
    }
    return deviceInterface
  }

  fileprivate var interfaceInterface: InterfaceInterface? {
    var interfaceInterface = InterfaceInterface()
    // Do a little type system dance to work with C's void* while we query the interface.
    let kr = withUnsafeMutablePointer(to: &interfaceInterface.wrapped) {
      $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { voidStar in
        unwrapped.QueryInterface(wrapped, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), voidStar)
      }
    }
    guard kr == S_OK else {
      let code = String(format: "0x%08x", kr)
      logger.error("Error querying the interface interface: \(code)")
      return nil
    }
    return interfaceInterface
  }
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

  fileprivate func getInterfaceInterface(for ifaceHandle: io_service_t) throws
    -> InterfaceInterface
  {
    // First, we have to get the PlugIn interface
    var pluginInterface = PluginInterface()
    var score: sint32 = 0
    let kr = IOCreatePlugInInterfaceForService(
      ifaceHandle, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID,
      &pluginInterface.wrapped, &score)
    guard kr == KERN_SUCCESS else {
      throw USBError.generic("Failed to create plugin interface: \(kr)")
    }
    defer { _ = pluginInterface.unwrapped.Release(pluginInterface.wrapped) }
    // Now use the plugin interface to obtain the device interface.
    guard let interfaceInterface = pluginInterface.interfaceInterface else {
      throw USBError.generic("Error obtaining the interface interface")
    }
    logger.info("Successfully obtianed the interface interface: \(interfaceInterface)")
    return interfaceInterface
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
    var req = request  // Reassign to var to pass by ref
    return unwrapped.DeviceRequest(wrapped, &req)
  }

  var configCount: UInt8 {
    var count = UInt8(0)
    if case let res = unwrapped.GetNumberOfConfigurations(wrapped, &count), res != kIOReturnSuccess
    {
      // Caller will know something is wrong if there are 0 configurations.
      return UInt8(0)
    }
    return count
  }

  var configuration: UInt8 {
    var config: UInt8 = 0
    if case let res = unwrapped.GetConfiguration(wrapped, &config), res != kIOReturnSuccess {
      logger.error("Error getting the current configuration: (\(returnString(res)))")
      return 0
    }
    return config
  }

  func interfaceIterator(req: IOUSBFindInterfaceRequest) -> IOIterator {
    // Assign to var so we can pass by ref
    var req = req
    var itr: io_iterator_t = 0
    if case let res = unwrapped.CreateInterfaceIterator(wrapped, &req, &itr),
      res != kIOReturnSuccess
    {
      logger.error("Failed to create the interface iterator: \(returnString(res))")
      return IOIterator()
    }
    return IOIterator(itr: itr)
  }
}

// Wrappers for IOUSBDeviceInterface functions.
extension InterfaceInterface: CustomStringConvertible {

  var description: String {
    return "iface(class=\(clazz), subclass=\(subclass), protocol=\(proto), alt=\(alt))"
  }

  var clazz: UInt8 {
    var count = UInt8(0)
    if case let res = unwrapped.GetInterfaceClass(wrapped, &count), res != kIOReturnSuccess {
      logger.error("Failed to get the interface class: \(returnString(res))")
      return UInt8(0)
    }
    return count
  }

  var subclass: UInt8 {
    var subclass = UInt8(0)
    if case let res = unwrapped.GetInterfaceSubClass(wrapped, &subclass), res != kIOReturnSuccess {
      logger.error("Failed to get the interface subclass: \(returnString(res))")
      return UInt8(0)
    }
    return subclass
  }

  var proto: UInt8 {
    var proto = UInt8(0)
    if case let res = unwrapped.GetInterfaceProtocol(wrapped, &proto), res != kIOReturnSuccess {
      logger.error("Failed to get the interface protocol: \(returnString(res))")
      return UInt8(0)
    }
    return proto
  }

  var alt: UInt8 {
    var alt = UInt8(0)
    if case let res = unwrapped.GetInterfaceProtocol(wrapped, &alt), res != kIOReturnSuccess {
      logger.error("Failed to get the interface protocol: \(returnString(res))")
      return UInt8(0)
    }
    return alt
  }

  var endpointCount: UInt8 {
    var count = UInt8(0)
    if case let res = unwrapped.GetNumEndpoints(wrapped, &count), res != kIOReturnSuccess {
      logger.error("Failed to get the number of endpoints: \(returnString(res))")
      return UInt8(0)
    }
    return count
  }

  func open() {
    if case let res = unwrapped.USBInterfaceOpen(wrapped), res != kIOReturnSuccess {
      logger.error("Failed to open the interface: \(returnString(res))")
    }
  }

  func getProperties(forEndpoint idx: UInt8) -> EndpointProperties? {
    var props = EndpointProperties()
    if case let res = unwrapped.GetPipeProperties(
      wrapped, idx, &props.direction, &props.num, &props.transferType, &props.maxPacketSize,
      &props.interval),
      res != kIOReturnSuccess
    {
      logger.error("Failed to get endpoint properties: \(returnString(res))")
      return nil
    }
    return props
  }

  func read(endpoint: UInt8) {
    var buffer = Data(count: 512)
    var readLen = UInt32(512)
    var res: IOReturn = 0
    buffer.withUnsafeBytes {
      let voidStar = UnsafeMutableRawPointer(mutating: $0.baseAddress!)
      res = unwrapped.ReadPipe(wrapped, endpoint, voidStar, &readLen)
    }
    if res != kIOReturnSuccess {
      logger.error("Error reading from the endpoint: \(returnString(res))")
      return
    }
    logger.info("Read \(readLen) bytes")
    _ = buffer.prefix(Int(readLen)).map { String(format: "0x%02x", $0) }.joined(separator: " ")
    let decoded = String(decoding: buffer[4..<12], as: UTF8.self)
    logger.info("Received \(decoded) packet")
  }
}

internal struct EndpointProperties: CustomStringConvertible {
  var direction: UInt8 = 0
  var num: UInt8 = 0
  var transferType: UInt8 = 0
  var maxPacketSize: UInt16 = 0
  var interval: UInt8 = 0

  var description: String {
    "[endpoint dir=\(direction), num=\(num), trans=\(transferType), "
      + "maxSize=\(maxPacketSize), interval=\(interval)]"
  }
}
