// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSDesignSystem",
    platforms: [.visionOS("2.0"), .iOS(.v17)],
    products: [
        .library(name: "ILSDesignSystem", targets: ["ILSDesignSystem"]),
    ],
    dependencies: [
        .package(path: "../../Core/ILSFoundation")
    ],
    targets: [
        .target(
            name: "ILSDesignSystem",
            dependencies: ["ILSFoundation"],
            resources: [.process("Resources/Fonts")]
        )
    ]
)
