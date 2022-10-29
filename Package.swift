// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "mew-wallet-ios-networking",
  platforms: [
    .iOS(.v14),
    .macOS(.v12)
  ],
  products: [
    .library(
      name: "mew-wallet-ios-networking",
      targets: ["mew-wallet-ios-networking"]),
  ],
  dependencies: [
    .package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMajor(from: "4.0.0")),
    .package(url: "git@github.com:mewwallet/mew-wallet-ios-logger.git", .upToNextMajor(from: "1.0.0"))
  ],
  targets: [
    .target(
      name: "mew-wallet-ios-networking",
      dependencies: ["Starscream",
                     "mew-wallet-ios-logger"],
      path: "Sources"),
    .testTarget(
      name: "mew-wallet-ios-networkingTests",
      dependencies: ["mew-wallet-ios-networking"])
  ]
)
