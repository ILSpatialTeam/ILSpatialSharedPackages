// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ILSSharePlay",
    platforms: [.visionOS("26.0")],
    products: [
        .library(name: "ILSSharePlay", targets: ["ILSSharePlay"]),
    ],
    dependencies: [
        .package(path: "../../Core/ILSFoundation"),
        .package(path: "../../../Packages/CockpitDomain"),
    ],
    targets: [
        .target(
            name: "ILSSharePlay",
            dependencies: [
                .product(name: "ILSFoundation", package: "ILSFoundation"),
                .product(name: "CockpitDomain", package: "CockpitDomain"),
            ],
            linkerSettings: [
                .linkedFramework("GroupActivities"),
                .linkedFramework("Foundation"),
            ]
        ),
    ]
)
