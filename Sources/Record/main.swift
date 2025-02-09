import Logging

LoggingSystem.bootstrap { label in
  var handler = StreamLogHandler.standardError(label: label)
  handler.logLevel = .info
  return handler
}

RecordCommand.main()
