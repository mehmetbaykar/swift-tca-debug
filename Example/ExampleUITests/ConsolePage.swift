import SwiftXCUIPageMacros
import XCTest

@Page
struct ConsolePage<Origin: VerifiablePageObject>: OriginTrackedPage {
  let origin: Origin

  init(app: XCUIApplication, origin: Origin) {
    self.app = app
    self.origin = origin
  }

  init(app: XCUIApplication) {
    self.init(app: app, origin: Origin(app: app))
  }

  @Element(.any, .id("tca-debug.console"), actions: [.assertExists], verify: true)
  var consoleRoot: XCUIElement

  @Element(.button, .id("tca-debug.close-button"), verify: true)
  var closeButton: XCUIElement

  func close() -> Origin {
    PageNavigation.returnToOrigin(from: self) {
      tapCloseButton()
    }
  }
}
