import ArgumentParser

@main
struct RecordCommand: ParsableCommand {
  mutating func run() throws {
    debugPrint("Hello, world!")
  }
}

