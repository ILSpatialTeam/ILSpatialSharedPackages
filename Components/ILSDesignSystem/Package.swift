// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSDesignSystem",
    platforms: [.visionOS("2.0")],
    products: [
        .library(name: "ILSDesignSystem", targets: ["ILSDesignSystem"]),
    ],
    targets: [
        .target(name: "ILSDesignSystem")
    ]
)
