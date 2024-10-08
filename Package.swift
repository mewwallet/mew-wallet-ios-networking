// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "mew-wallet-ios-networking",
  platforms: [
    .iOS(.v14),
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "mew-wallet-ios-networking",
      targets: ["mew-wallet-ios-networking"]),
    .library(
      name: "mew-wallet-ios-networking-websocket",
      targets: ["mew-wallet-ios-networking-websocket"])
  ],
  dependencies: [
    .package(url: "git@github.com:mewwallet/mew-wallet-ios-extensions.git", .upToNextMajor(from: "2.0.0")),
    .package(url: "git@github.com:mewwallet/mew-wallet-ios-logger.git", .upToNextMajor(from: "2.0.1")),
    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "mew-wallet-ios-networking",
      dependencies: [
        "mew-wallet-ios-networking-websocket",
        .product(name: "mew-wallet-ios-extensions", package: "mew-wallet-ios-extensions"),
        .product(name: "mew-wallet-ios-logger", package: "mew-wallet-ios-logger")
      ],
      path: "mew-wallet-ios-networking",
      resources: [
        .copy("Privacy/PrivacyInfo.xcprivacy")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency=complete")
      ]
    ),
    .testTarget(
      name: "mew-wallet-ios-networking-tests",
      dependencies: [
        "mew-wallet-ios-networking",
      ],
      path: "Tests/mew-wallet-ios-networking-tests"
    ),
    
    // Websocket
    .target(
      name: "mew-wallet-ios-networking-websocket",
      dependencies: [
        .product(name: "mew-wallet-ios-extensions", package: "mew-wallet-ios-extensions"),
        .product(name: "mew-wallet-ios-logger", package: "mew-wallet-ios-logger")
      ],
      path: "mew-wallet-ios-networking-websocket",
      resources: [
        .copy("Privacy/PrivacyInfo.xcprivacy")
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency=complete")
      ]
    ),
    .testTarget(
      name: "mew-wallet-ios-networking-websocket-tests",
      dependencies: [
        "mew-wallet-ios-networking-websocket",
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      ],
      path: "Tests/mew-wallet-ios-networking-websocket-tests"
    )
  ]
)
