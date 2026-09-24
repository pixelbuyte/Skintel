// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkinstelMascot",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SkinstelMascot", targets: ["SkinstelMascot"])],
    targets: [.target(name: "SkinstelMascot", resources: [.process("Resources")])]
)
