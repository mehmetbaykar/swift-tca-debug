/// The four screen corners the floating debug button snaps to.
///
/// Corners are expressed in leading/trailing semantics and flip automatically
/// under right-to-left layout.
public enum FloatingCorner: String, CaseIterable, Codable, Hashable, Sendable {
  case topLeading
  case topTrailing
  case bottomLeading
  case bottomTrailing
}
