// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSFoundation",
    platforms: [.visionOS("2.0"), .iOS(.v17)],
    products: [
        .library(name: "ILSFoundation", type: .static, targets: ["ILSFoundation"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ILSFoundation",
            dependencies: []
        )
    ]
)
