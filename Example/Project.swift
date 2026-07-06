import ProjectDescription

let project = Project(
  name: "Example",
  packages: [
    .package(path: ".."),
    .remote(
      url: "https://github.com/mehmetbaykar/swift-xcui-page-macros",
      requirement: .exact("1.1.0")
    ),
  ],
  targets: [
    .target(
      name: "Example",
      destinations: .iOS,
      product: .app,
      bundleId: "com.baykarapps.tcadebug.Example",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .extendingDefault(with: [
        "UILaunchScreen": .dictionary([:])
      ]),
      buildableFolders: [
        "Example/Sources"
      ],
      dependencies: [
        .package(product: "TCADebug")
      ]
    ),
    .target(
      name: "ExampleUITests",
      destinations: .iOS,
      product: .uiTests,
      bundleId: "com.baykarapps.tcadebug.ExampleUITests",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .default,
      buildableFolders: [
        "ExampleUITests"
      ],
      dependencies: [
        .target(name: "Example"),
        .package(product: "SwiftXCUIPageMacros"),
      ]
    ),
    .target(
      name: "ExampleTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.baykarapps.tcadebug.ExampleTests",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .default,
      buildableFolders: [
        "ExampleTests"
      ],
      dependencies: [
        .target(name: "Example")
      ]
    ),
  ]
)
