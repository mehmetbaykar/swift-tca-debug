import SwiftXCUIPageMacros
import XCTest

@Page
struct ExamplePage: VerifiablePageObject {
  @Element(.button, .id("example.increment"), verify: true)
  var incrementButton: XCUIElement

  @Element(.button, .id("example.decrement"))
  var decrementButton: XCUIElement

  @Element(.button, .id("example.reset"))
  var resetButton: XCUIElement

  @Element(.button, .id("example.fetch"), verify: true)
  var fetchButton: XCUIElement

  @Element(.any, .id("example.post"), actions: [.assertExists])
  var firstPost: XCUIElement

  @Element(.any, .id("tca-debug.floating-button"), actions: [.tap])
  var floatingButton: XCUIElement

  func openConsole() throws -> ConsolePage<Self> {
    try PageNavigation.open(
      from: self,
      perform: {
        tapFloatingButton()
      }
    ) { app, origin in
      ConsolePage(app: app, origin: origin)
    }
  }
}
