// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TestApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "TestApp",
            targets: ["TestApp"]
        ),
    ],
    targets: [
        .target(
            name: "TestApp",
            path: "src"
        ),
        .testTarget(
            name: "TestAppTests",
            dependencies: ["TestApp"],
            path: "tests"
        ),
    ]
)
