import Foundation
import Logging
import Pulse

/// A swift-log backend that persists every log record into a Pulse ``LoggerStore``,
/// where it becomes visible in the in-app debug console.
///
/// Most apps install it with ``TCADebug/bootstrap(level:store:metadataProvider:additionalHandlers:)``.
/// Apps that already own their `LoggingSystem.bootstrap` call can compose this handler manually:
///
/// ```swift
/// LoggingSystem.bootstrap { label in
///   MultiplexLogHandler([
///     PulseLogHandler(label: label),
///     MyCrashReporterHandler(label: label),
///   ])
/// }
/// ```
public struct PulseLogHandler: LogHandler, Sendable {
  public var logLevel: Logger.Level
  public var metadata: Logger.Metadata
  public var metadataProvider: Logger.MetadataProvider?

  private let label: String
  private let store: LoggerStore

  /// - Parameters:
  ///   - label: The label of the logger this handler backs.
  ///   - store: The Pulse store that receives the messages. Defaults to ``LoggerStore/shared``.
  ///   - metadataProvider: Contextual metadata applied to every message, overriding handler
  ///     metadata while still being overridden by per-message metadata.
  public init(
    label: String,
    store: LoggerStore = .shared,
    metadataProvider: Logger.MetadataProvider? = nil
  ) {
    self.label = label
    self.store = store
    self.logLevel = .debug
    self.metadata = [:]
    self.metadataProvider = metadataProvider
  }

  public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { self.metadata[key] }
    set { self.metadata[key] = newValue }
  }

  public func log(event: LogEvent) {
    var merged = self.metadata
    if let providerMetadata = self.metadataProvider?.get(), !providerMetadata.isEmpty {
      merged.merge(providerMetadata) { _, provider in provider }
    }
    if let eventMetadata = event.metadata {
      merged.merge(eventMetadata) { _, message in message }
    }
    if let error = event.error {
      merged["error.message"] = .string(String(describing: error))
      merged["error.type"] = .string(String(reflecting: type(of: error)))
    }
    self.store.storeMessage(
      label: self.label,
      level: LoggerStore.Level(event.level),
      message: event.message.description,
      metadata: merged.isEmpty ? nil : merged.pulseMetadata,
      file: event.file,
      function: event.function,
      line: event.line
    )
  }
}

extension LoggerStore.Level {
  /// Maps a swift-log level onto the equivalent Pulse level.
  init(_ level: Logger.Level) {
    switch level {
    case .trace: self = .trace
    case .debug: self = .debug
    case .info: self = .info
    case .notice: self = .notice
    case .warning: self = .warning
    case .error: self = .error
    case .critical: self = .critical
    }
  }
}

extension Logger.Metadata {
  fileprivate var pulseMetadata: LoggerStore.Metadata {
    self.mapValues { .string($0.flattened) }
  }
}

extension Logger.MetadataValue {
  // Pulse metadata values are flat strings; nested swift-log values are rendered recursively.
  fileprivate var flattened: String {
    switch self {
    case .string(let string):
      return string
    case .stringConvertible(let convertible):
      return convertible.description
    case .dictionary(let dictionary):
      let entries =
        dictionary
        .map { "\($0): \($1.flattened)" }
        .sorted()
        .joined(separator: ", ")
      return "[\(entries)]"
    case .array(let values):
      return "[\(values.map(\.flattened).joined(separator: ", "))]"
    }
  }
}
