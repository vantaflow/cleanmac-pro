// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CleanMacPro",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CleanMacPro", targets: ["CleanMacPro"]),
        .executable(name: "CleanMacProSmoke", targets: ["CleanMacProSmoke"]),
        .library(name: "CleanCore", targets: ["CleanCore"]),
    ],
    targets: [
        .executableTarget(
            name: "CleanMacPro",
            dependencies: ["CleanCore"],
            path: "Sources/CleanMacPro"
        ),
        .executableTarget(
            name: "CleanMacProSmoke",
            dependencies: ["CleanCore"],
            path: "Sources/CleanMacProSmoke"
        ),
        .target(
            name: "CleanCore",
            path: "Sources/CleanCore"
        ),
        .testTarget(
            name: "CleanCoreTests",
            dependencies: ["CleanCore"],
            path: "Tests/CleanCoreTests"
        ),
    ]
)
