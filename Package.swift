// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MacCleanerCore",
            targets: ["MacCleanerCore"]
        ),
        .executable(
            name: "maccleaner",
            targets: ["MacCleanerCLI"]
        ),
        .executable(
            name: "MacCleanerApp",
            targets: ["MacCleanerApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "MacCleanerCore",
            path: "Sources/MacCleanerCore"
        ),
        .executableTarget(
            name: "MacCleanerCLI",
            dependencies: [
                "MacCleanerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/MacCleanerCLI"
        ),
        .executableTarget(
            name: "MacCleanerApp",
            dependencies: ["MacCleanerCore"],
            path: "Sources/MacCleanerApp"
        ),
        .testTarget(
            name: "MacCleanerCoreTests",
            dependencies: ["MacCleanerCore"],
            path: "Tests/MacCleanerCoreTests"
        ),
    ]
)
