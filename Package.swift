// swift-tools-version: 6.1
// Hikari Yaps — local speech-to-text for macOS (Apple Silicon)
import PackageDescription

let package = Package(
    name: "HikariYaps",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.0.0"),
        .package(url: "https://github.com/eastriverlee/LLM.swift.git", from: "2.1.0")
    ],
    targets: [
        .executableTarget(
            name: "HikariYaps",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "LLM", package: "LLM.swift")
            ],
            path: "Sources/HikariYaps",
            resources: [
                .process("Resources")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
