// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Scripts",
    platforms: [.macOS(.v11)],
    dependencies: [
        .package(url: "https://github.com/renaudjenny/MarketingScreenshots", from: "0.0.6"),
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