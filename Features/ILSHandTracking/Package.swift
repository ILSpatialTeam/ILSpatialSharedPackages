// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSHandTracking",
    platforms: [.visionOS("2.0")],
    products: [
        .library(name: "ILSHandTracking", targets: ["ILSHandTracking"]),
    ],
    dependencies: [
        .package(path: "../../Core/ILSEngine"),
        .package(path: "../../Core/ILSFoundation")
    ],
    targets: [
        .target(
            name: "ILSHandTracking",
            dependencies: [
                "ILSEngine",
                "ILSFoundation"
            ]
        )
    ]
)
