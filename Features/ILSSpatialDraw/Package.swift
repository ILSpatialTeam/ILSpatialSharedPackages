// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSSpatialDraw",
    platforms: [.visionOS("2.0")],
    products: [
        .library(name: "ILSSpatialDraw", targets: ["ILSSpatialDraw"]),
    ],
    dependencies: [
        .package(path: "../../Core/ILSEngine"),
        .package(path: "../../Core/ILSFoundation"),
        .package(path: "../ILSHandTracking"),
        .package(path: "../ILSSpatialAudio"),
        .package(path: "../ILSSharePlay")
    ],
    targets: [
        .target(
            name: "ILSSpatialDraw",
            dependencies: [
                "ILSEngine",
                "ILSFoundation",
                "ILSHandTracking",
                "ILSSpatialAudio",
                "ILSSharePlay"
            ]
        )
    ]
)
