// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CleanMacPro",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CleanMacPro", targets: ["CleanMacPro"]),
        .executable(name: "CleanMacProSmoke", targets: ["CleanMacProSmoke"]),
        .library(name: "CleanCore", targets: ["CleanCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.6.4"),
    ],
    targets: [
        .executableTarget(
            name: "CleanMacPro",
            dependencies: [
                "CleanCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/CleanMacPro"
        ),
        .executableTarget(
            name: "CleanMacProSmoke",
            dependencies: ["CleanCore"],
            path: "Sources/CleanMacProSmoke"
        ),
        .target(
            name: "CleanCore",
            path: "Sources/CleanCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CleanCoreTests",
            dependencies: ["CleanCore"],
            path: "Tests/CleanCoreTests"
        ),
    ]
)
