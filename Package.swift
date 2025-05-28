// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RiviAskAI",
    platforms: [
        .iOS(.v15), // Requires iOS 15.0 or later
        .macOS(.v12) // Requires macOS 12.0 or later
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RiviAskAI",
            targets: ["RiviAskAI"]
        ),
    ],
    targets: [
        .target(
            name: "RiviAskAI",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
    ]
)
