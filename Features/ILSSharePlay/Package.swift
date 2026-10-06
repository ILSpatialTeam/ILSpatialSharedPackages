// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSSharePlay",
    platforms: [.visionOS("2.0"), .macOS(.v12)],
    products: [
        .library(name: "ILSSharePlay", targets: ["ILSSharePlay"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ILSSharePlay",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("GroupActivities"),
                .linkedFramework("Foundation"),
            ]
        ),
    ]
)
