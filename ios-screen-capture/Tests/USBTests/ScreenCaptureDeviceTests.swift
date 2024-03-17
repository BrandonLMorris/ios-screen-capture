import XCTest

@testable import ios_screen_capture

let defaultUdid = "abcd1234"

final class ScreenCaptureDeviceTests: XCTestCase {

  func testObtainDevice_happyPath_worksFine() throws {
    XCTAssertNoThrow(
        try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: FakeDeviceProvider())
      )
  }

  func testObtainDevice_noDevices_throwsError() throws {
    let provider = FakeDeviceProvider()
    provider.devices = []
    XCTAssertThrowsError(
      try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: provider))
  }

  func testObtainDevice_multipleMatchingDevices_throwsError() throws {
    let provider = FakeDeviceProvider()
    provider.devices = [FakeDevice(), FakeDevice()]
    XCTAssertThrowsError(
      try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: provider))
  }

  func testObtainDevice_udidWithHyphens_removesForMatching() throws {
    let hyphenated = "--a-b-c-d-1-2-3-4--"
    XCTAssertNoThrow(
        try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: FakeDeviceProvider())
      )
  }
}

private final class FakeDeviceProvider: DeviceProvider {
  fileprivate var devices = [FakeDevice()]

  func connected() throws -> [Device] {
    return devices
  }
}

private final class FakeDevice: Device {
  var isOpen: Bool = false
  var configCount: Int = 0

  func open() throws {}

  func close() {}

  func reset() {}

  func activeConfig(refresh: Bool) -> Int { -1 }

  func setConfiguration(config: UInt8) {}

  func getInterface(withSubclass subclass: UInt8, withAlt alt: UInt8) -> InterfaceInterface? {
    nil
  }

  func control(index: UInt16) {}
  func registryEntry(forKey: String) -> String? {
    ["USB Serial Number": defaultUdid][forKey]
  }

}
