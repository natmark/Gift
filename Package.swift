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
    ],
    targets: [
        .target(name: "gift", dependencies: ["Commandant", "GiftKit"]),
        .target(name: "GiftKit", dependencies: []),
        .testTarget(name: "GiftKitTests", dependencies: ["GiftKit"]),
    ]
)
