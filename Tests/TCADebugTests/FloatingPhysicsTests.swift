import SwiftUI
import Testing

@testable import TCADebug

@Suite("FloatingPhysics")
struct FloatingPhysicsTests {
  // 400x800 screen, 56pt button, 12pt padding, no safe area.
  private let corners = FloatingPhysics.cornerPoints(
    in: CGSize(width: 400, height: 800),
    safeAreaInsets: EdgeInsets(),
    buttonSize: CGSize(width: 56, height: 56),
    padding: 12
  )

  @Test("zero velocity projects to the same point")
  func projectAtRest() {
    let point = CGPoint(x: 100, y: 200)
    let projected = FloatingPhysics.project(point, velocity: .zero)
    #expect(projected == point)
  }

  @Test("projection carries momentum forward")
  func projectWithVelocity() {
    let projected = FloatingPhysics.project(
      CGPoint(x: 100, y: 200),
      velocity: CGSize(width: 1000, height: -500)
    )
    // factor = (0.998 / 1000) / 0.002 = 0.499
    #expect(abs(projected.x - 599) < 1)
    #expect(abs(projected.y - (200 - 249.5)) < 1)
  }

  @Test("a flick wins over the geometrically nearest corner")
  func flickPicksProjectedCorner() {
    // Resting near bottom-trailing, flicked hard toward leading.
    let release = CGPoint(x: 360, y: 730)
    #expect(FloatingPhysics.nearestCorner(to: release, in: self.corners) == .bottomTrailing)

    let projected = FloatingPhysics.project(
      release, velocity: CGSize(width: -3000, height: 0)
    )
    #expect(FloatingPhysics.nearestCorner(to: projected, in: self.corners) == .bottomLeading)
  }

  @Test("corner points respect safe area and padding")
  func cornerPoints() {
    let corners = FloatingPhysics.cornerPoints(
      in: CGSize(width: 400, height: 800),
      safeAreaInsets: EdgeInsets(top: 50, leading: 0, bottom: 30, trailing: 0),
      buttonSize: CGSize(width: 56, height: 56),
      padding: 12
    )
    #expect(corners[.topLeading] == CGPoint(x: 40, y: 90))
    #expect(corners[.topTrailing] == CGPoint(x: 360, y: 90))
    #expect(corners[.bottomLeading] == CGPoint(x: 40, y: 730))
    #expect(corners[.bottomTrailing] == CGPoint(x: 360, y: 730))
  }

  @Test("corner points honor right-to-left layout direction")
  func cornerPointsRightToLeft() {
    let corners = FloatingPhysics.cornerPoints(
      in: CGSize(width: 400, height: 800),
      safeAreaInsets: EdgeInsets(top: 50, leading: 20, bottom: 30, trailing: 60),
      buttonSize: CGSize(width: 56, height: 56),
      padding: 12,
      layoutDirection: .rightToLeft
    )
    #expect(corners[.topLeading] == CGPoint(x: 300, y: 90))
    #expect(corners[.topTrailing] == CGPoint(x: 60, y: 90))
    #expect(corners[.bottomLeading] == CGPoint(x: 300, y: 730))
    #expect(corners[.bottomTrailing] == CGPoint(x: 60, y: 730))
  }

  @Test("equidistant points resolve in allCases order")
  func tieBreak() {
    let center = CGPoint(x: 200, y: 400)
    #expect(FloatingPhysics.nearestCorner(to: center, in: self.corners) == .topLeading)
  }
}
