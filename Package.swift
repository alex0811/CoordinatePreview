// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoordinatePreviewCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CoordinatePreviewCore", targets: ["CoordinatePreviewCore"])
    ],
    targets: [
        .target(
            name: "CoordinatePreviewCore",
            path: "CoordinatePreviewCore"
        ),
        .testTarget(
            name: "CoordinatePreviewCoreTests",
            dependencies: ["CoordinatePreviewCore"],
            path: "CoordinatePreviewCoreTests"
        )
    ]
)

