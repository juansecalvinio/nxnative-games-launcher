// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GamesLauncher",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "LauncherCore"),
        .executableTarget(name: "GamesLauncher", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
    ]
)
