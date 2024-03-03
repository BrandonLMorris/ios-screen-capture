import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os.log

class ScreenCaptureDevice {
  private let services: [io_object_t]

  private init(services: [io_object_t]) {
    self.services = services
    self.services.forEach { IOObjectRetain($0) }
  }

  deinit {
    self.services.forEach { IOObjectRelease($0) }
  }

  static func obtainDevice(withUdid udid: String) throws -> ScreenCaptureDevice {
    // Hyphens are removed in the USB properties
    let udidNoHyphens = udid.replacingOccurrences(of: "-", with: "")

    guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) else {
      throw ScreenCaptureError.deviceNotFound("No usb devices found")
    }
    var matching = [io_object_t]()
    for device in IOIterator.forDevices(matching: matchingDict) {
      if let deviceUdid = getUdid(for: device), deviceUdid == udidNoHyphens {
        os_log(.info, "Found matching service for device udid: %s", deviceUdid)
        matching.append(device)
      } else {
        IOObjectRelease(device)
      }
    }
    if matching.isEmpty {
      throw ScreenCaptureError.deviceNotFound("Could not find device with udid \(udid)")
    }
    return ScreenCaptureDevice(services: matching)
  }

  private static func getUdid(for device: io_object_t) -> String? {
    for regEntry in IOIterator.forRegistryEntries(on: device) {
      defer { IOObjectRelease(regEntry) }
      var deviceProperties: Unmanaged<CFMutableDictionary>?
      IORegistryEntryCreateCFProperties(regEntry, &deviceProperties, kCFAllocatorDefault, 0)
      if let properties = deviceProperties?.takeRetainedValue() as? [String: Any] {
        if let serial = properties["USB Serial Number"] as? String {
          return serial
        }
      }
    }
    return nil
  }
}

internal enum ScreenCaptureError: Error {
  case deviceNotFound(_ msg: String)
  case recordingConfigError(_ msg: String)
}
