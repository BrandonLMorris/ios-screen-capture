import ArgumentParser
import Foundation
import Logging

private let logger = Logger(label: "RecordCommand")

struct RecordCommand: ParsableCommand {
  @Option(name: .shortAndLong, help: "The UDID of the device to record (find with idevice_id -l)")
  var udid: String

  @Option(name: .shortAndLong, help: "Enable extra logging")
  var verbose: Bool = false

  mutating func run() throws {
    let recorder = Recorder(verbose: verbose)
    let task = DispatchWorkItem { [self] in
      do {
        // I solemnly swear I am up to no good...
        try recorder.start(forDeviceWithId: udid)
      } catch {
        logger.error("Error starting the recording! \(error)", metadata: ["udid": "\(udid)"])
      }
    }
    DispatchQueue.global().async(execute: task)

    logger.info("Press enter to stop...")
    _ = readLine()

    // ...mischief managed.
    try recorder.stop()
    logger.info("Recorder stopped", metadata: ["udid": "\(udid)"])
    task.cancel()
  }
}

enum RecordingError: Error {
  case unrecognizedPacket(_ msg: String)
  case recordingUninitialized(_ msg: String)
}
