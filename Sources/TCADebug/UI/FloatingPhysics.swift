import SwiftUI

// Fluid-interface math for the floating button, after Apple's "Designing Fluid
// Interfaces" (WWDC18): a released drag is projected forward using scroll-view
// deceleration, and the button snaps to the corner nearest the *projected* point,
// so a flick sends it across the screen.
enum FloatingPhysics {
  // UIScrollView.DecelerationRate.normal, hardcoded for cross-platform availability.
  static let decelerationRate: CGFloat = 0.998

  /// Projects a release position forward given the gesture's velocity in points/second.
  static func project(
    _ position: CGPoint,
    velocity: CGSize,
    decelerationRate: CGFloat = FloatingPhysics.decelerationRate
  ) -> CGPoint {
    // distance = (v / 1000) * rate / (1 - rate), with velocity in pt/s and rate per ms.
    let factor = (decelerationRate / 1000) / (1 - decelerationRate)
    return CGPoint(
      x: position.x + velocity.width * factor,
      y: position.y + velocity.height * factor
    )
  }

  /// The corner whose resting point is closest to `point`. Ties resolve in
  /// `FloatingCorner.allCases` order.
  static func nearestCorner(
    to point: CGPoint,
    in corners: [FloatingCorner: CGPoint]
  ) -> FloatingCorner {
    let candidates = FloatingCorner.allCases.compactMap { corner in
      corners[corner].map { (corner: corner, point: $0) }
    }
    let nearest = candidates.min { lhs, rhs in
      squaredDistance(point, lhs.point) < squaredDistance(point, rhs.point)
    }
    return nearest?.corner ?? .bottomTrailing
  }

  /// Resting center points for all four corners, inset by the safe area and padding.
  static func cornerPoints(
    in size: CGSize,
    safeAreaInsets: EdgeInsets,
    buttonSize: CGSize,
    padding: CGFloat,
    layoutDirection: LayoutDirection = .leftToRight
  ) -> [FloatingCorner: CGPoint] {
    let physicalLeadingX = safeAreaInsets.leading + padding + buttonSize.width / 2
    let physicalTrailingX = size.width - safeAreaInsets.trailing - padding - buttonSize.width / 2
    let leadingX = layoutDirection == .rightToLeft ? physicalTrailingX : physicalLeadingX
    let trailingX = layoutDirection == .rightToLeft ? physicalLeadingX : physicalTrailingX
    let topY = safeAreaInsets.top + padding + buttonSize.height / 2
    let bottomY = size.height - safeAreaInsets.bottom - padding - buttonSize.height / 2
    return [
      .topLeading: CGPoint(x: leadingX, y: topY),
      .topTrailing: CGPoint(x: trailingX, y: topY),
      .bottomLeading: CGPoint(x: leadingX, y: bottomY),
      .bottomTrailing: CGPoint(x: trailingX, y: bottomY),
    ]
  }

  private static func squaredDistance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
    let dx = lhs.x - rhs.x
    let dy = lhs.y - rhs.y
    return dx * dx + dy * dy
  }
}
