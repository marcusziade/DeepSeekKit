// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyAIApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/marcusziade/DeepSeekKit.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyAIApp",
            dependencies: ["DeepSeekKit"]
        )
    ]
)