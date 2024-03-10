import ArgumentParser

@main
struct RecordCommand: ParsableCommand {
  @Option(name: .shortAndLong, help: "The UDID of the device to record (find with idevice_id -l)")
  var udid: String

  mutating func run() throws {
    var screenCaptureDevice = try ScreenCaptureDevice.obtainDevice(withUdid: udid)
    // I solemnly swear I am up to no good...
    screenCaptureDevice = try screenCaptureDevice.activate()
    print("Activated. We are clear for launch.")
    screenCaptureDevice.initializeRecording()
    print("Press enter to stop...", terminator: "")
    _ = readLine()
    // ...mischief managed.
    screenCaptureDevice.deactivate()
  }
}
