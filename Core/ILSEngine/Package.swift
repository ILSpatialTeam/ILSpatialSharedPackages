// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSEngine",
    platforms: [.visionOS("2.0"), .iOS(.v17)],
    products: [
        .library(name: "ILSEngine", type: .static, targets: ["ILSEngine"]),
    ],
    dependencies: [
        .package(path: "../ILSFoundation"),
        .package(path: "../../RealityKitContent/ILSRealityAssets")
    ],
    targets: [
        .target(
            name: "ILSEngine",
            dependencies: [
                .product(name: "ILSFoundation", package: "ILSFoundation"),
                .product(name: "ILSRealityAssets", package: "ILSRealityAssets")
            ]
        )
    ]
)
