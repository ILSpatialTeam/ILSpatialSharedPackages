// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSRealityAssets",
    platforms: [.visionOS("2.0")],
    products: [
        .library(name: "ILSRealityAssets", targets: ["ILSRealityAssets"]),
    ],
    targets: [
        .target(name: "ILSRealityAssets", resources: [.process("ILSRealityAssets.rkassets")])
    ]
)
