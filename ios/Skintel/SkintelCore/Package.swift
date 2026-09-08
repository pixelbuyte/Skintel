// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkintelCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkintelCore", targets: ["SkintelCore"]),
    ],
    targets: [
        .target(
            name: "SkintelCore",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "SkintelCoreTests",
            dependencies: ["SkintelCore"]
        ),
    ]
)
