import XCTest

@testable import ios_screen_capture

let defaultUdid = "abcd1234"

final class ScreenCaptureDeviceTests: XCTestCase {

  // MARK: Obtain device tests

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
      try ScreenCaptureDevice.obtainDevice(withUdid: hyphenated, from: FakeDeviceProvider())
    )
  }

  // MARK: Activation tests

  func testActivate_normalFlow_sendsControl() throws {
    let provider = FakeDeviceProvider()
    let fake = provider.devices.first!
    let device = try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: provider)

    _ = try device.activate(reconnectBackoff: 0.0)

    XCTAssertEqual(fake.controlCallCount, 1)
  }

  func testActivate_normalFlow_reconnectsProperly() throws {
    let provider = FakeDeviceProvider()
    let reconnect = provider.reconnectDevices.first!
    let device = try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: provider)

    _ = try device.activate(reconnectBackoff: 0.0)

    XCTAssertGreaterThan(reconnect.openCallCount, 0)
  }

  func testActivate_normalFlow_setsConfigurationAfterReconnect() throws {
    let provider = FakeDeviceProvider()
    let reconnect = provider.reconnectDevices.first!
    let device = try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: provider)

    _ = try device.activate(reconnectBackoff: 0.0)

    XCTAssertEqual(reconnect.config, 6)
  }

  func testActivate_cannotReconect_failsWithError() throws {
    let provider = FakeDeviceProvider()
    provider.reconnectDevices = []  // Nothing to reconnect to
    let device = try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: provider)

    XCTAssertThrowsError(try device.activate(reconnectBackoff: 0.0))
  }

  // MARK: Deactivation tests

  func testDeactivate_normalFlow_sendsControl() throws {
    let provider = FakeDeviceProvider()
    let fake = provider.devices.first!
    let device = try ScreenCaptureDevice.obtainDevice(withUdid: defaultUdid, from: provider)

    device.deactivate()

    XCTAssertEqual(fake.controlCallCount, 1)
  }
}

// MARK: Testing fakes

private final class FakeDeviceProvider: DeviceProvider {
  fileprivate var devices = [FakeDevice()]
  // For simplicity, reconnecting (invoking the provider after the first time)
  // returns an activated device.
  fileprivate var reconnectDevices = [FakeDevice(activated: true)]
  private var callCount = 0

  func connected() throws -> [Device] {
    callCount += 1
    if callCount > 1 {
      return reconnectDevices
    }
    return devices
  }
}

private final class FakeDevice: Device {
  var isOpen: Bool = false
  var configCount: Int = 0

  init(activated: Bool = false) {
    if activated { configCount = 6 }
  }

  fileprivate var openCallCount = 0
  func open() throws {
    openCallCount += 1
  }

  func close() {}

  func reset() {}

  func activeConfig(refresh: Bool) -> Int { -1 }

  var config = 0
  func setConfiguration(config: UInt8) { self.config = Int(config) }

  func getInterface(withSubclass subclass: UInt8, withAlt alt: UInt8) -> InterfaceInterface? {
    nil
  }

  fileprivate var controlCallCount = 0
  func control(index: UInt16) {
    controlCallCount += 1
  }

  func registryEntry(forKey: String) -> String? {
    ["USB Serial Number": defaultUdid][forKey]
  }

}
