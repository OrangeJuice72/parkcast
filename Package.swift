// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParkCastCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "ParkCastCore", targets: ["ParkCastCore"])],
    targets: [
        .target(name: "ParkCastCore"),
        .testTarget(name: "ParkCastCoreTests", dependencies: ["ParkCastCore"])
    ]
)
