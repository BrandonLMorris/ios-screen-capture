import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os.log

private let udidRegistryKey = "USB Serial Number"

struct ScreenCaptureDevice {
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
    return ScreenCaptureDevice(device: matching.first!)
  }
}

internal enum ScreenCaptureError: Error {
  case deviceNotFound(_ msg: String)
  case multipleDevicesFound(_ msg: String)
  case recordingConfigError(_ msg: String)
}
