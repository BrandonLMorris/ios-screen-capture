import Testing

@testable import USB

let defaultUdid = "abcd1234"

final class DeviceCaptureStreamTests {

  // MARK: Obtain device tests

  @Test func obtainDevice_happyPath_worksFine() throws {
    #expect(throws: Never.self) {
      try createDeviceCaptureStream(
        withUdid: defaultUdid, from: FakeDeviceProvider(), withBackoff: 0.0)
    }
  }

  @Test func obtainDevice_noDevices_throwsError() throws {
    let provider = FakeDeviceProvider()
    provider.devices = []
    #expect(throws: ScreenCaptureError.self) {
      try createDeviceCaptureStream(withUdid: defaultUdid, from: provider, withBackoff: 0.0)
    }
  }

  @Test func obtainDevice_multipleMatchingDevices_throwsError() throws {
    let provider = FakeDeviceProvider()
    provider.devices = [FakeDevice(), FakeDevice()]
    #expect(throws: ScreenCaptureError.self) {
      try createDeviceCaptureStream(withUdid: defaultUdid, from: provider, withBackoff: 0.0)
    }
  }

  @Test func obtainDevice_udidWithHyphens_removesForMatching() throws {
    let hyphenated = "--a-b-c-d-1-2-3-4--"
    #expect(throws: Never.self) {
      try createDeviceCaptureStream(
        withUdid: hyphenated, from: FakeDeviceProvider(), withBackoff: 0.0)
    }
  }

  // MARK: Activation tests

  @Test func activate_normalFlow_sendsControl() throws {
    let provider = FakeDeviceProvider()
    let fake = provider.devices.first!
    let device = try createDeviceCaptureStream(
      withUdid: defaultUdid, from: provider, withBackoff: 0.0)

    _ = try device.activate()

    #expect(fake.controlCallCount == 1)
  }

  @Test func activate_normalFlow_reconnectsProperly() throws {
    let provider = FakeDeviceProvider()
    let reconnect = provider.reconnectDevices.first!
    let device = try createDeviceCaptureStream(
      withUdid: defaultUdid, from: provider, withBackoff: 0.0)

    _ = try device.activate()

    #expect(reconnect.openCallCount > 0)
  }

  @Test func activate_normalFlow_setsConfigurationAfterReconnect() throws {
    let provider = FakeDeviceProvider()
    let reconnect = provider.reconnectDevices.first!
    let device = try createDeviceCaptureStream(
      withUdid: defaultUdid, from: provider, withBackoff: 0.0)

    _ = try device.activate()

    #expect(reconnect.config == 6)
  }

  @Test func testActivate_cannotReconect_failsWithError() throws {
    let provider = FakeDeviceProvider()
    provider.reconnectDevices = []  // Nothing to reconnect to
    let device = try createDeviceCaptureStream(
      withUdid: defaultUdid, from: provider, withBackoff: 0.0)

    #expect(throws: ScreenCaptureError.self) { try device.activate() }
  }

  // MARK: Deactivation tests

  @Test func deactivate_normalFlow_sendsControl() throws {
    let provider = FakeDeviceProvider()
    let fake = provider.devices.first!
    let device = try createDeviceCaptureStream(
      withUdid: defaultUdid, from: provider, withBackoff: 0.0)

    device.deactivate()

    #expect(fake.controlCallCount == 1)
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
