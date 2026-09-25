// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSSpatialAudio",
    platforms: [.visionOS("2.0"), .macOS("15.0")],
    products: [
        .library(name: "ILSSpatialAudio", targets: ["ILSSpatialAudio"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ILSSpatialAudio",
            dependencies: []
        )
    ]
)
