// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RideCore",
    platforms: [.macOS(.v13), .watchOS(.v11)],
    products: [.library(name: "RideCore", targets: ["RideCore"])],
    targets: [
        .target(name: "RideCore"),
        .testTarget(name: "RideCoreTests", dependencies: ["RideCore"])
    ]
)
