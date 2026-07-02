// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MDrop",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MDropCore", targets: ["MDropCore"]),
        .executable(name: "MDrop", targets: ["MDropApp"]),
        .executable(name: "MDropHarness", targets: ["MDropHarness"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.2"
        )
    ],
    targets: [
        .target(name: "MDropCore"),
        .executableTarget(
            name: "MDropApp",
            dependencies: [
                "MDropCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "@executable_path/../Frameworks"
                ])
            ]
        ),
        .executableTarget(name: "MDropHarness"),
        .testTarget(
            name: "MDropCoreTests",
            dependencies: ["MDropCore"]
        ),
        .testTarget(
            name: "MDropAppTests",
            dependencies: ["MDropApp", "MDropCore"]
        )
    ]
)
