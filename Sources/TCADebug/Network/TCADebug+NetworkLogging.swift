import Pulse
import PulseProxy

extension TCADebug {
  /// Captures all `URLSession` traffic — including `URLSession.shared` and async/await
  /// conveniences — into the given Pulse store, where it appears in the console's
  /// network view.
  ///
  /// > Warning: This relies on Pulse's swizzling-based proxy (`NetworkLogger.enableProxy`),
  /// > which instruments private `URLSession` internals. It is intended for debug builds;
  /// > production-cautious apps should instead wrap an explicitly owned session with
  /// > Pulse's `URLSessionProxy`/`URLSessionProxyDelegate` and inject it as a dependency.
  ///
  /// - Parameter store: The Pulse store that receives the traffic. Defaults to
  ///   ``LoggerStore/shared``.
  public static func enableNetworkLogging(store: LoggerStore = .shared) {
    NetworkLogger.enableProxy(logger: NetworkLogger(store: store))
  }
}
