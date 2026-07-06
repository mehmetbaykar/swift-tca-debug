import ComposableArchitecture
import Dispatch
import Logging

extension Reducer {
  /// Logs every received action and the resulting state diff through swift-log.
  ///
  /// ```swift
  /// var logger = Logger(label: "tca")
  /// logger.logLevel = .debug
  ///
  /// let store = Store(initialState: AppFeature.State()) {
  ///   AppFeature().debugLog(logger)
  /// }
  /// ```
  ///
  /// Unlike `_printChanges`, this logs in **all** build configurations — gate the call
  /// site with `#if DEBUG` before shipping.
  public func debugLog(_ logger: Logger) -> some Reducer<State, Action> {
    DebugLogReducer(base: self, configuration: DebugLogConfiguration(logger: logger))
  }

  /// Logs received actions and state diffs with a custom ``DebugLogConfiguration``.
  ///
  /// ```swift
  /// AppFeature().debugLog(
  ///   DebugLogConfiguration(logger: logger, logStateDiffs: false)
  /// )
  /// ```
  public func debugLog(
    _ configuration: DebugLogConfiguration<State, Action>
  ) -> some Reducer<State, Action> {
    DebugLogReducer(base: self, configuration: configuration)
  }
}

struct DebugLogReducer<Base: Reducer>: Reducer {
  let base: Base
  let configuration: DebugLogConfiguration<Base.State, Base.Action>

  func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
    let oldState = state
    let effects = self.base.reduce(into: &state, action: action)
    let configuration = self.configuration
    // Action/State are not Sendable in general; values are moved onto the serial logging
    // queue without further sharing — the same strategy TCA's own printer uses.
    let captured = UncheckedSendable((action: action, oldState: oldState, newState: state))
    DebugLogQueue.queue.async {
      let (action, oldState, newState) = captured.wrappedValue
      let diff: String? =
        configuration.logStateDiffs
        ? ComposableArchitecture.diff(oldState, newState)
        : nil

      let message: String
      if let format = configuration.format {
        message = format(action, diff)
      } else {
        message = Self.defaultMessage(
          action: action,
          diff: diff,
          logActions: configuration.logActions,
          logStateDiffs: configuration.logStateDiffs
        )
      }
      guard message.isEmpty == false else { return }
      configuration.logger.log(level: configuration.level, "\(message)")
    }
    return effects
  }

  static func defaultMessage(
    action: Base.Action,
    diff: String?,
    logActions: Bool,
    logStateDiffs: Bool
  ) -> String {
    var message = ""
    if logActions {
      message.append("received action:\n")
      customDump(action, to: &message, indent: 2)
      message.append("\n")
    }
    if logStateDiffs {
      message.append(diff.map { "\($0)\n" } ?? "  (No state changes)\n")
    }
    return message
  }
}

// Serial queue that keeps dump/diff cost off the reducer's call stack.
enum DebugLogQueue {
  static let queue = DispatchQueue(label: "swift-tca-debug.debug-log")

  // Test hook: blocks until every enqueued log has been emitted.
  static func flush() {
    self.queue.sync {}
  }
}
