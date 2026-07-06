// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "swift-tca-debug",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
    .tvOS(.v18),
    .watchOS(.v11),
    .visionOS(.v2),
  ],
  products: [
    .library(name: "TCADebug", targets: ["TCADebug"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.0"),
    .package(url: "https://github.com/kean/Pulse", from: "5.2.3"),
    .package(url: "https://github.com/apple/swift-log", from: "1.13.2"),
  ],
  targets: [
    .target(
      name: "TCADebug",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Pulse", package: "Pulse"),
        .product(name: "PulseProxy", package: "Pulse"),
        // PulseUI powers the in-app console and is only linked where it is shown:
        // - macOS: PulseUI ships no console for macOS; the shared store is inspected
        //   with the Pulse mac app instead.
        // - visionOS: Pulse 5.2.x calls SwiftUI's `glassEffect`, which every visionOS
        //   SDK marks unavailable, so PulseUI does not compile for visionOS. Logging
        //   (Pulse + PulseProxy) still works there. Re-add visionOS once upstream
        //   guards the call (RichTextViewSearchToobar-ios.swift).
        .product(
          name: "PulseUI",
          package: "Pulse",
          condition: .when(platforms: [.iOS, .tvOS, .watchOS])
        ),
      ]
    ),
    .testTarget(
      name: "TCADebugTests",
      dependencies: [
        .target(name: "TCADebug")
      ]
    ),
  ]
)
