import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import Logging

private let logger = Logger(label: "Device")
private let transmissionSize: Int = 4096

public protocol Device {
  var isOpen: Bool { get }
  var configCount: Int { get }

  func open() throws
  func close()
  func reset()

  func activeConfig(refresh: Bool) -> Int
  func setConfiguration(config: UInt8)

  func getInterface(withSubclass subclass: UInt8, withAlt alt: UInt8) -> InterfaceInterface?
  func control(index: UInt16)
  func registryEntry(forKey: String) -> String?
}

public protocol DeviceProvider {
  func connected() throws -> [any Device]
}

final internal class USBDevice: Device {
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
      logger.warning("Failed to get the number of configurations")
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
      logger.warning("Error sending control message! \(returnString(res))")
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

final public class USBDeviceProvider: DeviceProvider {
  public init() {}
  public func connected() throws -> [any Device] {
    var connected = [USBDevice]()
    for service in try IOIterator.usbDevices() {
      connected.append(USBDevice(service))
    }
    return connected
  }
}

/// Device protocol implementation.
extension USBDevice {
  func open() throws {
    if case let res = deviceInterface.open(), res != kIOReturnSuccess {
      throw USBError.generic("Unable to open device! \(returnString(res))")
    }
    isOpen = true
  }

  func close() {
    if case let res = deviceInterface.close(), res != kIOReturnSuccess {
      logger.warning(
        "Error closing the device",
        metadata: ["returnString": "\(returnString(res))"])
    }
    isOpen = false
  }

  func reset() {
    if case let res = deviceInterface.reset(), res != kIOReturnSuccess {
      logger.warning(
        "Error resetting the device",
        metadata: ["retString": "\(returnString(res))"])
    }
    isOpen = false
  }

  func hardReset() {
    if case let res = deviceInterface.hardReset(), res != kIOReturnSuccess {
      logger.warning(
        "Error resetting the device",
        metadata: ["retString": "\(returnString(res))"])
    }
    isOpen = false
    Thread.sleep(forTimeInterval: TimeInterval(0.5))
  }

  func setConfiguration(config: UInt8) {
    if case let cnt = configCount, cnt < config {
      logger.warning("Cannot set configuration \(config); only \(cnt) found")
      return
    }
    if case let res = deviceInterface.setConfiguration(config: config), res != kIOReturnSuccess {
      logger.warning("Error settting configuration \(config): \(returnString(res))")
      return
    }
    logger.debug("Configuration \(config) successfully set")
  }
}

extension PluginInterface {

  fileprivate var deviceInterface: DeviceInterface? {
    var deviceInterface = DeviceInterface()
    // Do a little type system dance to work with C's void* while we query the interface.
    let kr = withUnsafeMutablePointer(to: &deviceInterface.wrapped) {
      $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { voidStar in
        unwrapped.QueryInterface(
          wrapped, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID.cfuuid), voidStar)
      }
    }
    guard kr == S_OK else {
      let code = String(format: "0x%08x", kr)
      logger.warning("Error querying the device interface: \(code)")
      return nil
    }
    return deviceInterface
  }

  fileprivate var interfaceInterface: InterfaceInterface? {
    var interfaceInterface = InterfaceInterface()
    // Do a little type system dance to work with C's void* while we query the interface.
    let kr = withUnsafeMutablePointer(to: &interfaceInterface.wrapped) {
      $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { voidStar in
        unwrapped.QueryInterface(
          wrapped, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID.cfuuid), voidStar)
      }
    }
    guard kr == S_OK else {
      let code = String(format: "0x%08x", kr)
      logger.warning("Error querying the interface interface: \(code)")
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
      self.serviceHandle, kIOUSBDeviceUserClientTypeID.cfuuid, kIOCFPlugInInterfaceID.cfuuid,
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
      ifaceHandle, kIOUSBInterfaceUserClientTypeID.cfuuid, kIOCFPlugInInterfaceID.cfuuid,
      &pluginInterface.wrapped, &score)
    guard kr == KERN_SUCCESS else {
      throw USBError.generic("Failed to create plugin interface: \(kr)")
    }
    defer { _ = pluginInterface.unwrapped.Release(pluginInterface.wrapped) }
    // Now use the plugin interface to obtain the device interface.
    guard let interfaceInterface = pluginInterface.interfaceInterface else {
      throw USBError.generic("Error obtaining the interface interface")
    }
    logger.debug("Successfully obtianed the interface interface: \(interfaceInterface)")
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
      logger.warning("Error getting the current configuration: (\(returnString(res)))")
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
      logger.warning("Failed to create the interface iterator: \(returnString(res))")
      return IOIterator()
    }
    return IOIterator(itr: itr)
  }
}

// Wrappers for IOUSBDeviceInterface functions.
extension InterfaceInterface: CustomStringConvertible {

  public var description: String {
    return "iface(class=\(clazz), subclass=\(subclass), protocol=\(proto), alt=\(alt))"
  }

  var clazz: UInt8 {
    var count = UInt8(0)
    if case let res = unwrapped.GetInterfaceClass(wrapped, &count), res != kIOReturnSuccess {
      logger.warning("Failed to get the interface class: \(returnString(res))")
      return UInt8(0)
    }
    return count
  }

  var subclass: UInt8 {
    var subclass = UInt8(0)
    if case let res = unwrapped.GetInterfaceSubClass(wrapped, &subclass), res != kIOReturnSuccess {
      logger.warning("Failed to get the interface subclass: \(returnString(res))")
      return UInt8(0)
    }
    return subclass
  }

  var proto: UInt8 {
    var proto = UInt8(0)
    if case let res = unwrapped.GetInterfaceProtocol(wrapped, &proto), res != kIOReturnSuccess {
      logger.warning("Failed to get the interface protocol: \(returnString(res))")
      return UInt8(0)
    }
    return proto
  }

  var alt: UInt8 {
    var alt = UInt8(0)
    if case let res = unwrapped.GetInterfaceProtocol(wrapped, &alt), res != kIOReturnSuccess {
      logger.warning("Failed to get the interface protocol: \(returnString(res))")
      return UInt8(0)
    }
    return alt
  }

  var endpointCount: UInt8 {
    var count = UInt8(0)
    if case let res = unwrapped.GetNumEndpoints(wrapped, &count), res != kIOReturnSuccess {
      logger.warning("Failed to get the number of endpoints: \(returnString(res))")
      return UInt8(0)
    }
    return count
  }

  func open() {
    if case let res = unwrapped.USBInterfaceOpen(wrapped), res != kIOReturnSuccess {
      logger.warning("Failed to open the interface: \(returnString(res))")
    }
  }

  func getProperties(forEndpoint idx: UInt8) -> EndpointProperties? {
    var props = EndpointProperties()
    if case let res = unwrapped.GetPipeProperties(
      wrapped, idx, &props.direction, &props.num, &props.transferType, &props.maxPacketSize,
      &props.interval),
      res != kIOReturnSuccess
    {
      logger.warning("Failed to get endpoint properties: \(returnString(res))")
      return nil
    }
    return props
  }

  func read(endpoint: UInt8) -> Data? {
    var buffer = Data(count: transmissionSize)
    var readLen = UInt32(transmissionSize)
    var totalRead = 0
    let res: IOReturn = buffer.withUnsafeMutableBytes {
      unwrapped.ReadPipe(wrapped, endpoint, $0.baseAddress!, &readLen)
    }
    if res != kIOReturnSuccess {
      logger.warning("Error reading from the endpoint: \(returnString(res))")
      return nil
    }
    totalRead += Int(readLen)
    while readLen == transmissionSize {
      // More to read
      var extra = Data(count: transmissionSize)
      let res: IOReturn = extra.withUnsafeMutableBytes {
        unwrapped.ReadPipe(wrapped, endpoint, $0.baseAddress!, &readLen)
      }
      if res != kIOReturnSuccess {
        break
      }
      totalRead += Int(readLen)
      buffer.append(extra.prefix(Int(readLen)))
    }
    return buffer.prefix(totalRead)
  }

  func write(_ toSend: Data, to endpoint: UInt8) -> Bool {
    var data = toSend
    // TODO break up packets larger than transmissionSize
    let res = data.withUnsafeMutableBytes {
      unwrapped.WritePipe(wrapped, endpoint, $0.baseAddress!, UInt32(toSend.count))
    }
    if res != kIOReturnSuccess {
      logger.warning("Error writing to the endpoint: \(returnString(res))")
      return false
    }
    return true
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
