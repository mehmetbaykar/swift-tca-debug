import Logging

/// Customizes what ``ComposableArchitecture/Reducer/debugLog(_:)-1nrok`` emits and how.
public struct DebugLogConfiguration<State, Action>: Sendable {
  /// The destination logger. Bring your own — its label and level configuration are respected.
  public var logger: Logger

  /// The level every message is emitted at. Defaults to `.debug`.
  ///
  /// The logger still applies its own `logLevel` filter, so set `logger.logLevel`
  /// to this level or lower when you want these messages to appear.
  public var level: Logger.Level

  /// Whether received actions are included in the built-in format. Defaults to `true`.
  public var logActions: Bool

  /// Whether state diffs are computed and included. Defaults to `true`.
  ///
  /// Diffing copies and dumps the whole state — switch this off for cheap action-only
  /// logging on features with large state.
  public var logStateDiffs: Bool

  /// Replaces the built-in message format entirely.
  ///
  /// Receives the action and the state diff (`nil` when the state did not change or
  /// ``logStateDiffs`` is `false`). This is also the redaction point for sensitive state.
  public var format: (@Sendable (_ action: Action, _ diff: String?) -> String)?

  public init(
    logger: Logger,
    level: Logger.Level = .debug,
    logActions: Bool = true,
    logStateDiffs: Bool = true,
    format: (@Sendable (_ action: Action, _ diff: String?) -> String)? = nil
  ) {
    self.logger = logger
    self.level = level
    self.logActions = logActions
    self.logStateDiffs = logStateDiffs
    self.format = format
  }
}
