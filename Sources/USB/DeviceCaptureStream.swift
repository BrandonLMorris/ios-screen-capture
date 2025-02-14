import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import Logging
import Packet
import Util
import os.log

private let logger = Logger(label: "ScreenCaptureDevice")

private let udidRegistryKey = "USB Serial Number"
private let recordingConfig = UInt8(6)
private let recordingInterfaceSubclass: UInt8 = 0x2a
private let recordingInterfaceAlt: UInt8 = 0xff

public protocol CaptureStream {
  /// Set up the stream for interaction.
  func activate() throws -> any CaptureStream

  /// Tear down the stream.
  func deactivate()

  /// Receive one or more packets from the stream.
  func readPackets() throws -> [any ScreenCapturePacket]

  /// Write a packet to the stream.
  func send(packet: any ScreenCapturePacket) throws
}

public func createDeviceCaptureStream(
  withUdid udid: String, from provider: any DeviceProvider = USBDeviceProvider(),
  withBackoff backoff: TimeInterval = 0.4
) throws -> CaptureStream {
  // Hyphens are removed in the USB properties
  let udidNoHyphens = udid.replacingOccurrences(of: "-", with: "")

  let matching = try provider.connected().filter {
    // Match on udid in the device's service registry
    $0.registryEntry(forKey: udidRegistryKey) == udidNoHyphens
  }

  guard !matching.isEmpty else {
    throw ScreenCaptureError.deviceNotFound("Could not find device with udid \(udid)")
  }
  guard matching.count == 1, let device = matching.first else {
    throw ScreenCaptureError.multipleDevicesFound(
      "\(matching.count) services matching udid \(udid). Unsure how to proceed; aborting.")
  }
  return DeviceCaptureStream(
    udid: udidNoHyphens, device: device, reconnectProvider: provider, withBackoff: backoff)
}

extension CaptureStream {
  public func ping() throws {
    try send(packet: Ping.instance)
  }
}

internal class DeviceCaptureStream: CaptureStream {
  private let udid: String
  private let device: Device
  private let reconnectProvider: (any DeviceProvider)?
  private let reconnectBackoff: TimeInterval
  private var iface: InterfaceInterface? = nil
  private var endpoints: Endpoints? = nil
  private var verbose: Bool = false

  internal init(
    udid: String, device: Device, reconnectProvider: (any DeviceProvider)?,
    withBackoff reconnectBackoff: TimeInterval
  ) {
    self.udid = udid
    self.device = device
    self.reconnectProvider = reconnectProvider
    self.reconnectBackoff = reconnectBackoff
  }

  /// Enable the USB configuration for screen recording.
  ///
  /// N.b. This action causes a disconnect, and it takes about 1 second before we can reconnect.
  /// Any previous reference to the device are invalid and should not be used.
  public func activate() throws -> any CaptureStream {
    controlActivation(activate: true)
    let newRef = try obtain(
      withRetries: 10, recordingInterface: true, withBackoff: reconnectBackoff)
    newRef.device.setConfiguration(config: recordingConfig)
    logger.debug("Current configuration is \(newRef.device.activeConfig(refresh: false))")
    try! newRef.device.open()
    claimEndpoints(verboseLogging: false)
    return newRef
  }

  /// Enable the USB configuration for screen recording.
  public func deactivate() {
    controlActivation(activate: false)
  }

  internal func claimEndpoints(verboseLogging: Bool) {
    self.verbose = verboseLogging
    guard
      let iface = device.getInterface(
        withSubclass: recordingInterfaceSubclass, withAlt: recordingInterfaceAlt)
    else {
      logger.warning("Failed to obtain the recording interface")
      return
    }
    iface.open()
    let endpoints = getEndpoints(for: iface)
    // 0 is control endpoint on every interface, so if it hasn't changed we
    // know we missed it.
    if endpoints.in == 0 || endpoints.out == 0 {
      logger.warning("Failed to find the endpoints for bulk transfer!")
      return
    }
    self.iface = iface
    self.endpoints = endpoints
  }

  public func readPackets() throws -> [ScreenCapturePacket] {
    guard let iface = iface, let endpoints = endpoints else {
      throw ScreenCaptureError.uninitialized(
        "Endpoints (\(String(describing: endpoints))) and/or interface (\(String(describing: iface)) nil; device not initialized for reading."
      )
    }
    guard let raw = iface.read(endpoint: endpoints.in) else {
      throw ScreenCaptureError.readError("Failed to read from device!")
    }
    logger.trace("Read \(raw.count) bytes from device")
    let statedLength = Int(raw[uint32: 0])
    if statedLength == raw.count {
      // We read exactly 1 packet
      let packet = try PacketParser.parse(from: raw)
      return [packet]
    }
    if statedLength < raw.count {
      // We read +1 packets
      var packets = [ScreenCapturePacket]()
      var idx = 0
      while idx < raw.count {
        let packetLen = Int(raw[uint32: idx])
        let packet = try PacketParser.parse(from: raw.subdata(in: idx..<idx + packetLen))
        packets.append(packet)
        idx += packetLen
      }
      return packets
    }
    if statedLength > raw.count {
      // We read <1 packet
      var fullPacket = Data(raw)
      var bytesRead = raw.count
      while bytesRead < statedLength {
        guard let additional = iface.read(endpoint: endpoints.in) else {
          throw ScreenCaptureError.readError("Failed to read from device!")
        }
        fullPacket.append(additional)
        bytesRead += additional.count
      }
      let packet = try PacketParser.parse(from: fullPacket)
      return [packet]
    }
    throw ScreenCaptureError.readError("This should never happen")
  }

  public func send(packet: any ScreenCapturePacket) throws {
    guard let iface = iface, let endpoints = endpoints else {
      throw ScreenCaptureError.uninitialized(
        "Endpoints (\(String(describing: endpoints))) and/or interface (\(String(describing: iface)) nil; device not initialized for reading."
      )
    }
    guard iface.write(packet.data, to: endpoints.out) else {
      throw ScreenCaptureError.writeError("Failed to write to device!")
    }
    logger.trace(
      "Wrote \(packet.data.count) bytes", metadata: ["packet-type": "\(type(of: packet))"])
  }

  /// Sends a ping packet to the device.
  public func ping() throws {
    try send(packet: Ping.instance)
  }

  private func getEndpoints(for iface: InterfaceInterface) -> Endpoints {
    var inIdx = UInt8(0)
    var outIdx = UInt8(0)
    for idx in 1...iface.endpointCount {
      let props = iface.getProperties(forEndpoint: UInt8(idx))!
      if props.transferType == kUSBBulk {
        if props.direction == kUSBIn {
          inIdx = UInt8(idx)
        } else {
          outIdx = UInt8(idx)
        }
      }
    }
    return (in: inIdx, out: outIdx)
  }

  private func controlActivation(activate: Bool) {
    try! device.open()
    device.control(index: activate ? enableRecordingIndex : disableRecordingIndex)
    device.reset()
    device.close()
  }

  private func obtain(
    withRetries maxAttempts: Int = 0, recordingInterface: Bool = false,
    withBackoff backoff: TimeInterval = 0.4
  ) throws
    -> DeviceCaptureStream
  {
    var newDevice: DeviceCaptureStream? = nil
    var attemptCount = 0
    let provider = reconnectProvider ?? USBDeviceProvider()
    repeat {
      newDevice =
        try? createDeviceCaptureStream(withUdid: self.udid, from: provider) as? DeviceCaptureStream
      try? newDevice?.device.open()
      attemptCount += 1
      if let d = newDevice, recordingInterface && d.device.configCount >= 6 {
        // The third eye has opened.
        logger.info("Successfully revealed hidden screen recording configuration")
        break
      } else {
        newDevice?.device.close()
        newDevice = nil
        Thread.sleep(forTimeInterval: backoff)
      }
    } while newDevice == nil && attemptCount < maxAttempts
    guard newDevice != nil else {
      throw ScreenCaptureError.recordingConfigError("Unable to connect")
    }
    logger.debug(
      "There are now \(String(describing: newDevice?.device.configCount)) configurations")
    return newDevice!
  }
}

internal enum ScreenCaptureError: Error {
  case deviceNotFound(_ msg: String)
  case multipleDevicesFound(_ msg: String)
  case recordingConfigError(_ msg: String)
  case uninitialized(_ msg: String)
  case readError(_ msg: String)
  case writeError(_ msg: String)
}
