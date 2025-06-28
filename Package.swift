// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepSeekKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
        .macCatalyst(.v16)
    ],
    products: [
        .library(
            name: "DeepSeekKit",
            targets: ["DeepSeekKit"]
        ),
        .executable(
            name: "deepseek-cli",
            targets: ["DeepSeekCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3")
    ],
    targets: [
        .target(
            name: "DeepSeekKit",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "DeepSeekCLI",
            dependencies: [
                "DeepSeekKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "DeepSeekKitTests",
            dependencies: ["DeepSeekKit"]
        )
    ]
)