import ArgumentParser
import Foundation

@main
struct RecordCommand: ParsableCommand {
  @Option(name: .shortAndLong, help: "The UDID of the device to record (find with idevice_id -l)")
  var udid: String

  mutating func run() throws {
    let recorder = Recorder()
    DispatchQueue.global().async { [self] in
      do {
        // I solemnly swear I am up to no good...
        try recorder.start(forDeviceWithId: udid)
      } catch {
        print("Error starting the recording! \(error)")
      }
    }

    print("Press enter to stop...", terminator: "")
    _ = readLine()

    // ...mischief managed.
    try recorder.stop()
  }
}

enum RecordingError: Error {
  case unrecognizedPacket(_ msg: String)
  case recordingUninitialized(_ msg: String)
}
