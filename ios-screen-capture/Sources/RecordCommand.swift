import ArgumentParser

@main
struct RecordCommand: ParsableCommand {
  @Option(name: .shortAndLong, help: "The UDID of the device to record (find with idevice_id -l)")
  var udid: String

  mutating func run() throws {
    let _ = try ScreenCaptureDevice.obtainDevice(withUdid: udid)
    let device = try USBDevice.getConnected().first!
    print("Device interface is... \(String(describing: device.deviceInterface!))")
  }
}
