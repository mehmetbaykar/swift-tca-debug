import Foundation
import Logging

// Test double: a reference-semantics handler so tests can observe what a Logger emitted.
final class CapturingLogHandler: LogHandler, @unchecked Sendable {
  private let lock = NSLock()
  private var capturedEvents: [LogEvent] = []

  var events: [LogEvent] {
    self.lock.withLock { self.capturedEvents }
  }

  var messages: [String] {
    self.events.map(\.message.description)
  }

  var logLevel: Logger.Level = .trace
  var metadata: Logger.Metadata = [:]
  var metadataProvider: Logger.MetadataProvider?

  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { self.metadata[key] }
    set { self.metadata[key] = newValue }
  }

  func log(event: LogEvent) {
    self.lock.withLock { self.capturedEvents.append(event) }
  }
}
