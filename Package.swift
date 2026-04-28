// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FunikiKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "FunikiKit", targets: ["FunikiKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FunikiKit",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FunikiKitTests",
            dependencies: ["FunikiKit"]
        ),
    ]
)
