import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os.log

private let udidRegistryKey = "USB Serial Number"
private let recordingConfig = UInt8(6)

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
    return newRef
  }

  /// Enable the USB configuration for screen recording.
  func deactivate() {
    controlActivation(activate: false)
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
