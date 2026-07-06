import ComposableArchitecture
import Logging
import Testing

@testable import TCADebug

private struct CounterFeature: Reducer {
  struct State: Equatable {
    var count = 0
  }

  enum Action {
    case increment
    case noop
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .increment:
      state.count += 1
      return .none
    case .noop:
      return .none
    }
  }
}

@Suite("Reducer.debugLog")
struct DebugLogReducerTests {
  private func makeLogger() -> (Logger, CapturingLogHandler) {
    let handler = CapturingLogHandler()
    let logger = Logger(label: "test") { _ in handler }
    return (logger, handler)
  }

  private func run<R: Reducer<CounterFeature.State, CounterFeature.Action>>(
    _ reducer: R,
    action: CounterFeature.Action = .increment
  ) -> CounterFeature.State {
    var state = CounterFeature.State()
    _ = reducer.reduce(into: &state, action: action)
    DebugLogQueue.flush()
    return state
  }

  @Test("logs the received action and the state diff")
  func actionAndDiff() throws {
    let (logger, handler) = self.makeLogger()
    _ = self.run(CounterFeature().debugLog(logger))

    let message = try #require(handler.messages.first)
    #expect(message.contains("received action:"))
    #expect(message.contains("increment"))
    #expect(message.contains("count: 0"))
    #expect(message.contains("count: 1"))
  }

  @Test("notes when the state did not change")
  func noStateChanges() throws {
    let (logger, handler) = self.makeLogger()
    _ = self.run(CounterFeature().debugLog(logger), action: .noop)

    let message = try #require(handler.messages.first)
    #expect(message.contains("(No state changes)"))
  }

  @Test("emits at the configured level, defaulting to debug")
  func level() throws {
    let (defaultLogger, defaultHandler) = self.makeLogger()
    _ = self.run(CounterFeature().debugLog(defaultLogger))
    #expect(try #require(defaultHandler.events.first).level == .debug)

    let (logger, handler) = self.makeLogger()
    _ = self.run(
      CounterFeature().debugLog(DebugLogConfiguration(logger: logger, level: .info))
    )
    #expect(try #require(handler.events.first).level == .info)
  }

  @Test("logStateDiffs: false skips the diff")
  func diffsDisabled() throws {
    let (logger, handler) = self.makeLogger()
    _ = self.run(
      CounterFeature().debugLog(
        DebugLogConfiguration(logger: logger, logStateDiffs: false)
      )
    )

    let message = try #require(handler.messages.first)
    #expect(message.contains("received action:"))
    #expect(!message.contains("count:"))
    #expect(!message.contains("(No state changes)"))
  }

  @Test("logActions: false skips the action dump")
  func actionsDisabled() throws {
    let (logger, handler) = self.makeLogger()
    _ = self.run(
      CounterFeature().debugLog(
        DebugLogConfiguration(logger: logger, logActions: false)
      )
    )

    let message = try #require(handler.messages.first)
    #expect(!message.contains("received action:"))
    #expect(message.contains("count: 1"))
  }

  @Test("a custom format replaces the built-in message entirely")
  func customFormat() throws {
    let (logger, handler) = self.makeLogger()
    _ = self.run(
      CounterFeature().debugLog(
        DebugLogConfiguration(logger: logger) { action, diff in
          "custom \(action) hasDiff=\(diff != nil)"
        }
      )
    )

    #expect(handler.messages == ["custom increment hasDiff=true"])
  }

  @Test("disabled action and diff logging skips empty emissions")
  func emptyBuiltInMessageSkipped() {
    let (logger, handler) = self.makeLogger()
    _ = self.run(
      CounterFeature().debugLog(
        DebugLogConfiguration(logger: logger, logActions: false, logStateDiffs: false)
      )
    )

    #expect(handler.messages.isEmpty)
  }

  @Test("the wrapped reducer still mutates state")
  func passesThrough() {
    let (logger, _) = self.makeLogger()
    let state = self.run(CounterFeature().debugLog(logger))
    #expect(state.count == 1)
  }
}
