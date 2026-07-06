import SwiftXCUIPageMacros
import XCTest

@MainActor
final class ExampleUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  private func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    // The floating button persists its corner across launches; pin the default
    // so every test starts from a known position. PulseUI likewise persists its
    // console mode (defaulting to network-only), so pin it to All for
    // deterministic screenshots that show the TCA log entries.
    app.launchArguments += [
      "-tca-debug.corner", "bottomTrailing",
      "-com.github.kean.pulse.console.mode", "all",
    ]
    app.launch()
    return app
  }

  private func attachScreenshot(named name: String, of app: XCUIApplication) {
    // Let in-flight transitions (zoom, push) finish so exported README
    // screenshots are not captured mid-animation.
    Thread.sleep(forTimeInterval: 1)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testActionsConsoleAndNetworkFlow() throws {
    let app = launchApp()

    // 01 — demo screen ready.
    let example = ExamplePage(app: app).verifyDefaultScreen()
    attachScreenshot(named: "01-example", of: app)

    // Counter actions generate TCA action + state-diff logs.
    example.tapIncrementButton()
    example.tapIncrementButton()
    example.tapDecrementButton()

    // Real API request so the console's network view has traffic.
    example.tapFetchButton()
    XCTAssertTrue(
      example.firstPost.waitForExistence(timeout: 30),
      "posts should load from the network"
    )

    // 02 — floating button morphs into the console.
    let console = try example.openConsole()
    attachScreenshot(named: "02-console-open", of: app)

    // 03 — the captured request opens into a network detail view.
    let networkEntry = app.staticTexts
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "typicode"))
      .firstMatch
    XCTAssertTrue(
      networkEntry.waitForExistence(timeout: 10),
      "console should list the captured network request"
    )
    networkEntry.tap()
    attachScreenshot(named: "03-network-logs", of: app)
    app.navigationBars.buttons.firstMatch.tap()

    // Close restores the demo screen.
    console.close().verifyDefaultScreen()
  }

  // The precise corner-snap physics is covered deterministically by FloatingPhysicsTests.
  // This UI check keeps the assertion coarse: the button moves toward the requested corner,
  // stays inside the window, and still opens the console afterward.
  func testFloatingButtonRemainsFunctionalAfterDrag() throws {
    let app = launchApp()

    let example = ExamplePage(app: app).verifyDefaultScreen()
    let button = example.floatingButton
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    let initialFrame = button.frame
    let windowFrame = app.windows.firstMatch.frame

    let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let target = app.windows.firstMatch.coordinate(
      withNormalizedOffset: CGVector(dx: 0.1, dy: 0.9)
    )
    start.press(forDuration: 0.3, thenDragTo: target)

    XCTAssertTrue(button.exists, "button should survive a drag interaction")
    let movedToExpectedCorner = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let draggedFrame = button.frame
        return draggedFrame.midX < initialFrame.midX - 80
          && draggedFrame.midY > windowFrame.midY
          && windowFrame.insetBy(dx: -1, dy: -1).contains(draggedFrame)
      },
      object: nil
    )
    movedToExpectedCorner.expectationDescription =
      "button should snap toward the lower-leading corner and remain inside the window"
    wait(for: [movedToExpectedCorner], timeout: 5)
    attachScreenshot(named: "04-after-drag", of: app)

    // Still opens the console after the interaction.
    let console = try example.openConsole()
    console.close().verifyDefaultScreen()
  }
}
