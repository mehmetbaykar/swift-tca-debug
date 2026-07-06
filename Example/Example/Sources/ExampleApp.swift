import ComposableArchitecture
import Logging
import SwiftUI
import TCADebug

@main
struct ExampleApp: App {
  @MainActor
  static let store = Store(initialState: AppFeature.State()) {
    #if DEBUG
      AppFeature().debugLog(tcaLogger)
    #else
      AppFeature()
    #endif
  }

  static let tcaLogger: Logger = {
    var logger = Logger(label: "tca")
    logger.logLevel = .debug
    return logger
  }()

  init() {
    #if DEBUG
      TCADebug.bootstrap()
      TCADebug.enableNetworkLogging()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: Self.store)
        #if DEBUG
          .debugConsoleOverlay()
        #endif
    }
  }
}
