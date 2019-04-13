// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Gift",
    products: [
        .library(
            name: "GiftKit",
            targets: ["GiftKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Carthage/Commandant.git", from: "0.15.0"),
        .package(url: "https://github.com/thoughtbot/Curry.git", from: "4.0.1"),
        .package(url: "https://github.com/Bouke/INI.git", from: "1.2.0"),
    ],
    targets: [
        .target(name: "gift", dependencies: ["Commandant", "Curry", "GiftKit"]),
        .target(name: "GiftKit", dependencies: ["INI"]),
        .testTarget(name: "GiftKitTests", dependencies: ["GiftKit"]),
    ]
)
