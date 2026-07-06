#if os(iOS) || os(tvOS) || os(watchOS)
  import Pulse
  import PulseUI
  import SwiftUI

  /// The Pulse console wrapped in a navigation stack, ready to present anywhere.
  ///
  /// PulseUI's own toolbar is left intact — the centered mode menu (All / Logs / Network),
  /// share, and context items. When `onClose` is provided, PulseUI's default leading close
  /// is suppressed and a trailing close button is shown instead.
  ///
  /// ```swift
  /// .fullScreenCover(isPresented: $isConsolePresented) {
  ///   DebugConsoleView { isConsolePresented = false }
  /// }
  /// ```
  ///
  /// > Note: PulseUI does not ship a console for macOS — on macOS, inspect the shared
  /// > store with the Pulse mac app instead. On visionOS the console is unavailable
  /// > because PulseUI 5.2.x does not compile there (its Liquid Glass code path uses
  /// > `glassEffect`, which the visionOS SDK marks unavailable); logging itself still
  /// > works on visionOS.
  public struct DebugConsoleView: View {
    private let store: LoggerStore
    private let onClose: (() -> Void)?

    /// - Parameters:
    ///   - store: The Pulse store to display. Defaults to ``LoggerStore/shared``.
    ///   - onClose: When non-`nil`, a trailing close button is shown and this closure runs
    ///     when it is tapped.
    public init(store: LoggerStore = .shared, onClose: (() -> Void)? = nil) {
      self.store = store
      self.onClose = onClose
    }

    public var body: some View {
      NavigationStack {
        self.consoleView
      }
      .accessibilityIdentifier(TCADebugAccessibility.console)
    }

    private var closeButton: some View {
      Button {
        self.onClose?()
      } label: {
        Image(systemName: "xmark")
      }
      .accessibilityLabel("Close debug console")
      .accessibilityIdentifier(TCADebugAccessibility.closeButton)
    }

    #if os(iOS)
      private var consoleView: some View {
        ConsoleView(store: self.store)
          // Suppress PulseUI's own leading close; we present our own trailing one.
          .closeButtonHidden()
          .toolbar {
            if self.onClose != nil {
              // `.confirmationAction` lands at the rightmost trailing slot — past
              // PulseUI's own share/context items.
              ToolbarItem(placement: .confirmationAction) {
                self.closeButton
              }
            }
          }
      }
    #else
      private var consoleView: some View {
        ConsoleView(store: self.store)
          .toolbar {
            if self.onClose != nil {
              ToolbarItem(placement: .cancellationAction) {
                self.closeButton
              }
            }
          }
      }
    #endif
  }
#endif
