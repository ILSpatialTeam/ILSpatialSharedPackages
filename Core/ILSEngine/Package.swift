// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSEngine",
    platforms: [.visionOS("2.0"), .iOS(.v17), .macOS("15.0")],
    products: [
        .library(name: "ILSEngine", type: .static, targets: ["ILSEngine"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ILSEngine",
            dependencies: []
        )
    ]
)
