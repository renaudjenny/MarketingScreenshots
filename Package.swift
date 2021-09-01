// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarketingScreenshots",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "MarketingScreenshots",
            targets: ["MarketingScreenshots"]),
    ],
    dependencies: [
        .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.13.0"),
        .package(url: "https://github.com/davidahouse/XCResultKit", from: "0.9.2"),
        .package(url: "https://github.com/JohnSundell/ShellOut", from: "2.3.0"),
    ],
    targets: [
        .target(
            name: "MarketingScreenshots",
            dependencies: ["XCResultKit", "XMLCoder", "ShellOut"]),
        .testTarget(
            name: "MarketingScreenshotsTests",
            dependencies: ["MarketingScreenshots"]),
    ]
)
