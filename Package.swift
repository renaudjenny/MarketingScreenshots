// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarketingScreenshots",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.1"),
        .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.15.0"),
        .package(url: "https://github.com/davidahouse/XCResultKit", from: "1.0.1"),
        .package(url: "https://github.com/JohnSundell/ShellOut", from: "2.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "MarketingScreenshots",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "XCResultKit", package: "XCResultKit"),
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "ShellOut", package: "ShellOut"),
            ],
            exclude: ["HelloWorldSample"]
        ),
        .testTarget(
            name: "MarketingScreenshotsTests",
            dependencies: ["MarketingScreenshots"],
            exclude: ["HelloWorldSample"]
        ),
    ]
)
