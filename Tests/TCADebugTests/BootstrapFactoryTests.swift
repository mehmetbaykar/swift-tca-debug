import Foundation
import Logging
import Pulse
import Testing

@testable import TCADebug

// `LoggingSystem.bootstrap` may run once per process, so these tests exercise the
// factory that `TCADebug.bootstrap` installs, not the global bootstrap itself.
//
// `@MainActor` because `LoggerStore.allMessages()` reads from `viewContext`, a
// main-queue Core Data context; fetching it from Swift Testing's cooperative-pool
// threads intermittently segfaulted inside `NSManagedObjectContext.fetch`.
@Suite("TCADebug.handlerFactory", .serialized)
@MainActor
struct BootstrapFactoryTests {
  private func makeStore() throws -> LoggerStore {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("tca-debug-tests-\(UUID().uuidString)")
    return try LoggerStore(storeURL: url, options: [.create, .synchronous, .inMemory])
  }

  @Test("without additional handlers it produces a leveled PulseLogHandler")
  func pulseOnly() throws {
    let store = try self.makeStore()
    let factory = TCADebug.handlerFactory(level: .info, store: store, additionalHandlers: [])

    let handler = factory("app", nil)

    #expect(handler is PulseLogHandler)
    #expect(handler.logLevel == .info)
  }

  @Test("additional handlers fan out alongside Pulse with the same level")
  func multiplexed() throws {
    let store = try self.makeStore()
    let capturing = CapturingLogHandler()
    let factory = TCADebug.handlerFactory(
      level: .debug,
      store: store,
      additionalHandlers: [{ _ in capturing }]
    )

    let handler = factory("app", nil)
    #expect(handler is MultiplexLogHandler)
    #expect(capturing.logLevel == .debug)

    let logger = Logger(label: "app") { _ in handler }
    logger.info("fan out")

    #expect(capturing.messages == ["fan out"])
    let stored = try store.allMessages()
    #expect(stored.map(\.text) == ["fan out"])
  }

  @Test("the metadata provider handed to the factory reaches the Pulse handler")
  func metadataProvider() throws {
    let store = try self.makeStore()
    let factory = TCADebug.handlerFactory(level: .debug, store: store, additionalHandlers: [])
    let provider = Logger.MetadataProvider { ["origin": "provider"] }

    let logger = Logger(label: "app") { label in factory(label, provider) }
    logger.info("with context")

    let message = try #require(try store.allMessages().first)
    #expect(message.metadata["origin"] == "provider")
  }
}
