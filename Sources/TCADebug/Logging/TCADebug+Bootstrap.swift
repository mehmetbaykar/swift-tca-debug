import Foundation
import Logging
import Pulse

/// Namespace for the package's process-wide configuration entry points.
public enum TCADebug {}

extension TCADebug {
  /// Installs a Pulse-backed handler as the process-wide swift-log backend.
  ///
  /// Every `Logger` created after this call writes into `store`, which is what the
  /// debug console displays.
  ///
  /// > Warning: `LoggingSystem.bootstrap` may run **once per process** — call this from
  /// > `App.init` (or `application(_:didFinishLaunchingWithOptions:)`) and never again.
  /// > If your app already bootstraps swift-log, do not call this; compose a
  /// > ``PulseLogHandler`` into your existing factory instead.
  ///
  /// ```swift
  /// @main struct MyApp: App {
  ///   init() {
  ///     #if DEBUG
  ///     TCADebug.bootstrap()
  ///     #endif
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - level: Default level for every installed handler. Defaults to `.debug`.
  ///   - store: The Pulse store that receives the messages. Defaults to ``LoggerStore/shared``.
  ///   - metadataProvider: Contextual metadata applied to every message.
  ///   - additionalHandlers: Extra backends (stdout, os.log, crash reporters, …) that receive
  ///     every log record alongside Pulse, fanned out through `MultiplexLogHandler`.
  public static func bootstrap(
    level: Logger.Level = .debug,
    store: LoggerStore = .shared,
    metadataProvider: Logger.MetadataProvider? = nil,
    additionalHandlers: [@Sendable (String) -> any LogHandler] = []
  ) {
    LoggingSystem.bootstrap(
      handlerFactory(level: level, store: store, additionalHandlers: additionalHandlers),
      metadataProvider: metadataProvider
    )
  }

  // Factored out so tests can exercise the factory without hitting the
  // once-per-process `LoggingSystem.bootstrap` restriction.
  static func handlerFactory(
    level: Logger.Level,
    store: LoggerStore,
    additionalHandlers: [@Sendable (String) -> any LogHandler]
  ) -> @Sendable (String, Logger.MetadataProvider?) -> any LogHandler {
    { label, metadataProvider in
      var pulse = PulseLogHandler(label: label, store: store, metadataProvider: metadataProvider)
      pulse.logLevel = level
      guard !additionalHandlers.isEmpty else { return pulse }
      var handlers: [any LogHandler] = [pulse]
      for makeHandler in additionalHandlers {
        var handler = makeHandler(label)
        handler.logLevel = level
        handlers.append(handler)
      }
      return MultiplexLogHandler(handlers, metadataProvider: metadataProvider)
    }
  }
}
