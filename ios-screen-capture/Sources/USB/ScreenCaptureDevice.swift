import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os.log

private let udidRegistryKey = "USB Serial Number"
private let recordingConfig = UInt8(6)
private let recordingInterfaceSubclass: UInt8 = 0x2a
private let recordingInterfaceAlt: UInt8 = 0xff

struct ScreenCaptureDevice {
  private let udid: String
  private let device: USBDevice

  static func obtainDevice(withUdid udid: String) throws -> ScreenCaptureDevice {
    // Hyphens are removed in the USB properties
    let udidNoHyphens = udid.replacingOccurrences(of: "-", with: "")

    let matching = try USBDevice.getConnected().filter {
      // Match on udid in the device's service registry
      $0.registryEntry(forKey: udidRegistryKey) == udidNoHyphens
    }

    guard !matching.isEmpty else {
      throw ScreenCaptureError.deviceNotFound("Could not find device with udid \(udid)")
    }
    guard matching.count == 1 else {
      throw ScreenCaptureError.multipleDevicesFound(
        "\(matching.count) services matching udid \(udid). Unsure how to proceed; aborting.")
    }
    return ScreenCaptureDevice(udid: udidNoHyphens, device: matching.first!)
  }

  /// Enable the USB configuration for screen recording.
  ///
  /// N.b. This action causes a disconnect, and it takes about 1 second before we can reconnect.
  /// Any previous reference to the device are invalid and should not be used.
  func activate() throws -> ScreenCaptureDevice {
    controlActivation(activate: true)
    let newRef = try! obtain(withRetries: 10, recordingInterface: true)
    newRef.device.setConfiguration(config: recordingConfig)
    logger.info("Current configuration is \(newRef.device.activeConfig())")
    try! newRef.device.open()
    return newRef
  }

  /// Enable the USB configuration for screen recording.
  func deactivate() {
    controlActivation(activate: false)
  }

  func initializeRecording() {
    guard
      let iface = device.getInterface(
        withSubclass: recordingInterfaceSubclass, withAlt: recordingInterfaceAlt)
    else {
      logger.error("Failed to obtain the recording interface")
      return
    }
    iface.open()
    let endpoints = getEndpoints(for: iface)
    // 0 is control endpoint on every interface, so if it hasn't changed we
    // know we missed it.
    if endpoints.in == 0 || endpoints.out == 0 {
      logger.error("Failed to find the endpoints for bulk transfer!")
      return
    }
    iface.read(endpoint: endpoints.in)
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

  private func obtain(withRetries maxAttempts: Int = 0, recordingInterface: Bool = false) throws
    -> ScreenCaptureDevice
  {
    var newDevice: ScreenCaptureDevice? = nil
    var attemptCount = 0
    repeat {
      newDevice = try? ScreenCaptureDevice.obtainDevice(withUdid: self.udid)
      try? newDevice?.device.open()
      attemptCount += 1
      if let d = newDevice, recordingInterface && d.device.configCount >= 6 {
        // The third eye has opened.
        logger.info("Successfully revealed hidden screen recording configuration")
        break
      } else {
        newDevice?.device.close()
        newDevice = nil
        Thread.sleep(forTimeInterval: 0.4)
      }
    } while newDevice == nil && attemptCount < maxAttempts
    guard newDevice != nil else {
      throw ScreenCaptureError.recordingConfigError("Unable to connect")
    }
    logger.info("There are now \(newDevice!.device.configCount) configurations")
    return newDevice!
  }
}

internal enum ScreenCaptureError: Error {
  case deviceNotFound(_ msg: String)
  case multipleDevicesFound(_ msg: String)
  case recordingConfigError(_ msg: String)
}
