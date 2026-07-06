import Foundation
import Logging
import Pulse
import Testing

@testable import TCADebug

// `LoggerStore.allMessages()` reads from `viewContext`, a main-queue Core Data
// context, so store reads must happen on the main actor. Swift Testing otherwise
// runs tests on cooperative-pool threads, which intermittently segfaulted inside
// `NSManagedObjectContext.fetch` (EXC_BAD_ACCESS).
@Suite("PulseLogHandler", .serialized)
@MainActor
struct PulseLogHandlerTests {
  private func makeStore() throws -> LoggerStore {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("tca-debug-tests-\(UUID().uuidString)")
    return try LoggerStore(storeURL: url, options: [.create, .synchronous, .inMemory])
  }

  private func makeLogger(
    label: String = "test",
    store: LoggerStore,
    metadataProvider: Logger.MetadataProvider? = nil,
    configure: (inout PulseLogHandler) -> Void = { _ in }
  ) -> Logger {
    Logger(label: label) { label in
      var handler = PulseLogHandler(
        label: label, store: store, metadataProvider: metadataProvider
      )
      handler.logLevel = .trace
      configure(&handler)
      return handler
    }
  }

  @Test("stores message text, label, file, function, and line")
  func storesMessage() throws {
    let store = try self.makeStore()
    let logger = self.makeLogger(label: "app", store: store)

    logger.info("hello pulse")

    let messages = try store.allMessages()
    let message = try #require(messages.first)
    #expect(messages.count == 1)
    #expect(message.text == "hello pulse")
    #expect(message.label == "app")
    #expect(message.file.hasSuffix("PulseLogHandlerTests.swift"))
    #expect(!message.function.isEmpty)
    #expect(message.line > 0)
  }

  @Test("maps every swift-log level onto the equivalent Pulse level")
  func levelMapping() throws {
    let pairs: [(Logger.Level, LoggerStore.Level)] = [
      (.trace, .trace), (.debug, .debug), (.info, .info), (.notice, .notice),
      (.warning, .warning), (.error, .error), (.critical, .critical),
    ]
    for (logLevel, pulseLevel) in pairs {
      #expect(LoggerStore.Level(logLevel) == pulseLevel)
    }

    let store = try self.makeStore()
    let logger = self.makeLogger(store: store)
    logger.warning("careful")
    let message = try #require(try store.allMessages().first)
    #expect(message.level == LoggerStore.Level.warning.rawValue)
  }

  @Test("merges metadata with handler < provider < message precedence")
  func metadataPrecedence() throws {
    let store = try self.makeStore()
    let provider = Logger.MetadataProvider {
      ["origin": "provider", "provider-wins": "provider", "message-wins": "provider"]
    }
    let logger = self.makeLogger(store: store, metadataProvider: provider) { handler in
      handler[metadataKey: "provider-wins"] = "handler"
      handler[metadataKey: "message-wins"] = "handler"
    }

    logger.info("metadata", metadata: ["message-wins": "message"])

    let message = try #require(try store.allMessages().first)
    #expect(message.metadata["origin"] == "provider")
    #expect(message.metadata["provider-wins"] == "provider")
    #expect(message.metadata["message-wins"] == "message")
  }

  @Test("flattens nested metadata values into strings")
  func nestedMetadata() throws {
    let store = try self.makeStore()
    let logger = self.makeLogger(store: store)

    logger.info(
      "nested",
      metadata: [
        "dict": .dictionary(["a": "1", "b": "2"]),
        "list": .array(["x", .stringConvertible(42)]),
      ]
    )

    // Pulse's key-value encoding sanitizes stored metadata by stripping spaces.
    let message = try #require(try store.allMessages().first)
    #expect(message.metadata["dict"] == "[a:1,b:2]")
    #expect(message.metadata["list"] == "[x,42]")
  }

  @Test("folds the event's error into metadata")
  func errorMetadata() throws {
    struct Failure: Error {}
    let store = try self.makeStore()
    let logger = self.makeLogger(store: store)

    logger.error("boom", error: Failure())

    let message = try #require(try store.allMessages().first)
    #expect(message.metadata["error.message"]?.contains("Failure") == true)
    #expect(message.metadata["error.type"]?.contains("Failure") == true)
  }
}
