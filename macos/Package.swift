// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AwayBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "AwayCore"),
        .executableTarget(name: "AwayBar", dependencies: ["AwayCore"]),
        .testTarget(name: "AwayCoreTests", dependencies: ["AwayCore"]),
    ]
)
