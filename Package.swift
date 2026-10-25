// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Smart Sort 2.0 targets compile with strict concurrency checking.
let strictConcurrency: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "RiviSmartSort",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16), // Requires iOS 16.0 or later
        .macOS(.v12) // Requires macOS 12.0 or later
    ],
    products: [
        // Smart Sort 2.0: the shared contract, its runtime, the SwiftUI elements and their bindings.
        .library(
            name: "RiviSmartSort",
            targets: ["RiviSmartSortContract", "RiviSmartSortRuntime", "RiviSmartSortElements", "RiviSmartSortUI"]
        ),
    ],
    targets: [
        // The SwiftUI elements: chips, banner, ask sheet, button, dialogs, spotlight.
        .target(
            name: "RiviSmartSortElements",
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/en.lproj"),
                .process("Resources/ar.lproj")
            ]
        ),
        // Pure: types, reconcile, selectors, adapters, chips, i18n. No networking, clocks or UI.
        .target(
            name: "RiviSmartSortContract",
            resources: [.copy("Resources/smart-sort")],
            swiftSettings: strictConcurrency
        ),
        // Executes the contract's commands: HTTP, the ranking stream, timers, cancellation.
        .target(
            name: "RiviSmartSortRuntime",
            dependencies: ["RiviSmartSortContract"],
            swiftSettings: strictConcurrency
        ),
        // The tenant-facing facade and the bindings that drive the elements.
        .target(
            name: "RiviSmartSortUI",
            dependencies: ["RiviSmartSortRuntime", "RiviSmartSortElements"],
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "RiviSmartSortTests",
            dependencies: ["RiviSmartSortContract", "RiviSmartSortRuntime", "RiviSmartSortUI"],
            resources: [.copy("TestData")],
            swiftSettings: strictConcurrency
        ),
    ]
)
