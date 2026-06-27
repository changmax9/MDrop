// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MDrop",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MDropCore", targets: ["MDropCore"]),
        .executable(name: "MDrop", targets: ["MDropApp"])
    ],
    targets: [
        .target(name: "MDropCore"),
        .executableTarget(
            name: "MDropApp",
            dependencies: ["MDropCore"]
        ),
        .testTarget(
            name: "MDropCoreTests",
            dependencies: ["MDropCore"]
        )
    ]
)
