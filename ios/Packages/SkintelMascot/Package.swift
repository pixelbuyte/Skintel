// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkintelMascot",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkintelMascot", targets: ["SkintelMascot"]),
    ],
    targets: [
        // Pose math and drawing data only: no UI framework, testable anywhere.
        .target(name: "MascotRig"),
        // The SwiftUI droplet, its body parts and the playground.
        .target(name: "SkintelMascot", dependencies: ["MascotRig"]),
        .testTarget(name: "MascotRigTests", dependencies: ["MascotRig"]),
    ]
)
