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
    try! device.open()
    logger.info("Starting with \(device.configCount) configurations")
    if device.configCount == recordingUsbConfiguration {
      return self
    }
    device.control(index: enableRecordingIndex)
    device.hardReset()

    var newDevice: ScreenCaptureDevice? = nil
    var attemptCount = 0
    repeat {
      newDevice = try? ScreenCaptureDevice.obtainDevice(withUdid: self.udid)
      try? newDevice?.device.open()
      attemptCount += 1
      if let d = newDevice, d.device.configCount >= 6 {
        // The third eye has opened.
        logger.info("Successfully enabled hidden screen recording configuration")
        break
      } else {
        newDevice?.device.close()
        newDevice = nil
        Thread.sleep(forTimeInterval: 0.4)
      }
    } while newDevice == nil  && attemptCount < 10
    guard newDevice != nil else {
      throw ScreenCaptureError.recordingConfigError(
        "Unable to reconnect after sending control signal")
    }
    logger.info("There are now \(newDevice!.device.configCount) configurations")
    return newDevice!
  }

  func deactivate() { /* TODO */  }
}

internal enum ScreenCaptureError: Error {
  case deviceNotFound(_ msg: String)
  case multipleDevicesFound(_ msg: String)
  case recordingConfigError(_ msg: String)
}
