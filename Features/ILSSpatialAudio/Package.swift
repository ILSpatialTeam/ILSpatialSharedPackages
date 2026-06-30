// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSSpatialAudio",
    platforms: [.visionOS("2.0")],
    products: [
        .library(name: "ILSSpatialAudio", targets: ["ILSSpatialAudio"]),
    ],
    dependencies: [
        .package(path: "../../Core/ILSEngine"),
        .package(path: "../../Core/ILSFoundation")
    ],
    targets: [
        .target(
            name: "ILSSpatialAudio",
            dependencies: [
                "ILSEngine",
                "ILSFoundation"
            ]
        )
    ]
)
