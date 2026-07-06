#if os(iOS) || os(tvOS) || os(watchOS)
  import Pulse
  import SwiftUI

  extension View {
    /// Overlays a draggable, corner-snapping floating button that expands into the
    /// full-screen debug console when tapped.
    ///
    /// Unavailable on macOS and visionOS — see ``DebugConsoleView`` for why; logging
    /// still works on both.
    ///
    /// Apply once, to the root view:
    ///
    /// ```swift
    /// WindowGroup {
    ///   AppView(store: store)
    ///     #if DEBUG
    ///     .debugConsoleOverlay()
    ///     #endif
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - isEnabled: When `false`, nothing is added to the hierarchy.
    ///   - store: The Pulse store the console displays. Defaults to ``LoggerStore/shared``.
    ///   - initialCorner: Where the button rests on first launch. The last corner is
    ///     persisted across launches.
    public func debugConsoleOverlay(
      isEnabled: Bool = true,
      store: LoggerStore = .shared,
      initialCorner: FloatingCorner = .bottomTrailing
    ) -> some View {
      self.debugConsoleOverlay(
        isEnabled: isEnabled,
        store: store,
        initialCorner: initialCorner
      ) {
        FloatingDebugButtonLabel()
      }
    }

    /// Overlays the floating debug console button with a custom button label.
    @ViewBuilder
    public func debugConsoleOverlay(
      isEnabled: Bool = true,
      store: LoggerStore = .shared,
      initialCorner: FloatingCorner = .bottomTrailing,
      @ViewBuilder buttonLabel: @escaping () -> some View
    ) -> some View {
      if isEnabled {
        self.overlay {
          DebugConsoleOverlay(
            store: store,
            initialCorner: initialCorner,
            buttonLabel: buttonLabel
          )
        }
      } else {
        self
      }
    }
  }

  /// The default floating button label: a ladybug on a solid circle.
  struct FloatingDebugButtonLabel: View {
    var body: some View {
      Image(systemName: "ladybug.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.tint)
    }
  }

  struct DebugConsoleOverlay<ButtonLabel: View>: View {
    let store: LoggerStore
    let initialCorner: FloatingCorner
    @ViewBuilder let buttonLabel: () -> ButtonLabel

    @Environment(\.displayScale) private var displayScale
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var isConsoleOpen = false
    @State private var anchor: CGPoint = .zero
    @State private var didPlaceButton = false
    @GestureState(resetTransaction: Self.nonAnimatedTransaction)
    private var dragOffset: CGSize = .zero
    @AppStorage("tca-debug.corner") private var persistedCorner = ""
    @Namespace private var zoom

    private static var buttonSize: CGFloat { 56 }
    private static var padding: CGFloat { 12 }
    private static var zoomID: String { "tca-debug.console.zoom" }
    private static var coordinateSpaceName: String { "tca-debug.overlay" }
    private static var nonAnimatedTransaction: Transaction {
      var transaction = Transaction(animation: nil)
      transaction.disablesAnimations = true
      return transaction
    }

    private var corner: FloatingCorner {
      FloatingCorner(rawValue: self.persistedCorner) ?? self.initialCorner
    }

    var body: some View {
      GeometryReader { geometry in
        let corners = FloatingPhysics.cornerPoints(
          in: geometry.size,
          safeAreaInsets: geometry.safeAreaInsets,
          buttonSize: CGSize(width: Self.buttonSize, height: Self.buttonSize),
          padding: Self.padding,
          layoutDirection: self.layoutDirection
        )
        let buttonPosition = self.pixelAligned(self.anchor)
        self.button(corners: corners)
          .position(buttonPosition)
          .offset(x: self.dragOffset.width, y: self.dragOffset.height)
          .transaction { transaction in
            if self.dragOffset != .zero {
              transaction = Self.nonAnimatedTransaction
            }
          }
          .onAppear {
            if !self.didPlaceButton {
              self.anchor = corners[self.corner] ?? .zero
              self.didPlaceButton = true
            }
          }
          .onChange(of: geometry.size) {
            // Re-clamp to the current corner on rotation / window resize.
            self.anchor = corners[self.corner] ?? self.anchor
          }
          .onChange(of: geometry.safeAreaInsets) {
            self.anchor = corners[self.corner] ?? self.anchor
          }
          .onChange(of: self.layoutDirection) {
            self.anchor = corners[self.corner] ?? self.anchor
          }
      }
      .coordinateSpace(name: Self.coordinateSpaceName)
      .fullScreenCover(isPresented: self.$isConsoleOpen) {
        self.consoleCover
      }
    }

    // The console, presented with the system zoom transition so it expands from the button.
    @ViewBuilder
    private var consoleCover: some View {
      let view = DebugConsoleView(store: self.store) {
        self.isConsoleOpen = false
      }
      #if os(watchOS)
        view
      #else
        view.navigationTransition(.zoom(sourceID: Self.zoomID, in: self.zoom))
      #endif
    }

    @ViewBuilder
    private func button(corners: [FloatingCorner: CGPoint]) -> some View {
      #if os(watchOS)
        let shell = self.buttonShell {
          self.buttonCore()
        }
      #else
        let shell = self.buttonShell {
          self.buttonTransitionSource()
        }
      #endif

      #if os(tvOS) || os(watchOS)
        shell
          .onTapGesture {
            self.openConsole()
          }
      #else
        shell
          .gesture(
            self.dragGesture(corners: corners)
              .exclusively(
                before: TapGesture().onEnded {
                  self.openConsole()
                }
              )
          )
      #endif
    }

    private func buttonTransitionSource() -> some View {
      self.buttonCore()
        .matchedTransitionSource(id: Self.zoomID, in: self.zoom) { source in
          source
            .clipShape(RoundedRectangle(cornerRadius: Self.buttonSize / 2, style: .continuous))
            .shadow(color: .clear, radius: 0)
        }
    }

    @ViewBuilder
    private func buttonShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
      ZStack {
        FloatingDebugButtonShadow(size: Self.buttonSize)
        content()
      }
      .frame(width: Self.buttonSize, height: Self.buttonSize)
      .contentShape(Circle())
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Debug console")
      .accessibilityAddTraits(.isButton)
      .accessibilityIdentifier(TCADebugAccessibility.floatingButton)
    }

    private func buttonCore() -> some View {
      self.buttonLabel()
        .frame(width: Self.buttonSize, height: Self.buttonSize)
        // Solid fill, not a material: a material re-samples the blurred content behind it
        // every frame as the button moves, which shimmers/flickers during a drag.
        // Use a concrete color instead of `ShapeStyle.background`; the latter can inherit
        // the surrounding backdrop context and visibly shimmer while the view is moving.
        .background(FloatingDebugButtonBackground())
        .clipShape(Circle())
    }

    private func openConsole() {
      self.isConsoleOpen = true
    }

    #if !os(tvOS) && !os(watchOS)
      private func dragGesture(corners: [FloatingCorner: CGPoint]) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named(Self.coordinateSpaceName))
          .updating(self.$dragOffset) { value, state, transaction in
            transaction = Self.nonAnimatedTransaction
            state = value.translation
          }
          .onEnded { value in
            let restingAnchor = self.pixelAligned(self.anchor)
            let release = CGPoint(
              x: restingAnchor.x + value.translation.width,
              y: restingAnchor.y + value.translation.height
            )
            let projected = FloatingPhysics.project(release, velocity: value.velocity)
            let target = FloatingPhysics.nearestCorner(to: projected, in: corners)
            let targetPoint = corners[target] ?? release
            // Commit the absolute release point first so the auto-resetting drag offset
            // doesn't snap the button back to its old corner, then spring to the target.
            withTransaction(Self.nonAnimatedTransaction) {
              self.anchor = release
              self.persistedCorner = target.rawValue
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              self.anchor = targetPoint
            }
          }
      }
    #endif

    private func pixelAligned(_ point: CGPoint) -> CGPoint {
      guard self.displayScale > 0 else { return point }
      return CGPoint(
        x: (point.x * self.displayScale).rounded() / self.displayScale,
        y: (point.y * self.displayScale).rounded() / self.displayScale
      )
    }
  }

  private struct FloatingDebugButtonBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
      Circle().fill(self.colorScheme == .dark ? Color.black : Color.white)
    }
  }

  private struct FloatingDebugButtonShadow: View {
    let size: CGFloat

    var body: some View {
      FloatingDebugButtonBackground()
        .frame(width: self.size, height: self.size)
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }
#endif
