// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarketBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MarketBar", targets: ["MarketBar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MarketBar",
            dependencies: [],
            path: "Sources/MarketBar"
        ),
        .testTarget(
            name: "MarketBarTests",
            dependencies: ["MarketBar"],
            path: "Tests/MarketBarTests"
        )
    ]
)
