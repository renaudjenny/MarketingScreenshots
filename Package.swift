// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarketingScreenshots",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "MarketingScreenshots",
            targets: ["MarketingScreenshots"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.15.0"),
        .package(url: "https://github.com/davidahouse/XCResultKit", from: "1.0.1"),
        .package(url: "https://github.com/JohnSundell/ShellOut", from: "2.3.0"),
    ],
    targets: [
        .target(
            name: "MarketingScreenshots",
            dependencies: ["XCResultKit", "XMLCoder", "ShellOut"],
            exclude: ["HelloWorldSample"]
        ),
        .testTarget(
            name: "MarketingScreenshotsTests",
            dependencies: ["MarketingScreenshots"],
            exclude: ["HelloWorldSample"]
        ),
    ]
)
