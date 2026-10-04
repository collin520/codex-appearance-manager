// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexAppearanceManager",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexAppearanceCore", targets: ["CodexAppearanceCore"]),
        .library(name: "CodexAppearanceUI", targets: ["CodexAppearanceUI"]),
        .executable(name: "CodexAppearanceApp", targets: ["CodexAppearanceLauncher"]),
        .executable(name: "CodexAppearanceTestRunner", targets: ["CodexAppearanceTestRunner"])
    ],
    targets: [
        .target(name: "CodexAppearanceCore"),
        .target(
            name: "CodexAppearanceUI",
            dependencies: ["CodexAppearanceCore"],
            path: "Sources/CodexAppearanceApp",
            resources: [.copy("Resources")]
        ),
        .executableTarget(
            name: "CodexAppearanceLauncher",
            dependencies: ["CodexAppearanceUI"],
            path: "Sources/CodexAppearanceLauncher"
        ),
        .executableTarget(
            name: "CodexAppearanceTestRunner",
            dependencies: ["CodexAppearanceCore", "CodexAppearanceUI"]
        )
    ]
)
