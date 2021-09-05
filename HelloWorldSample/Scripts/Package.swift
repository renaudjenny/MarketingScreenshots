// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Scripts",
    platforms: [.macOS(.v11)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(
            name: "Scripts",
            dependencies: ["MarketingScreenshots"]),
        .testTarget(
            name: "ScriptsTests",
            dependencies: ["Scripts"]),
    ]
)
