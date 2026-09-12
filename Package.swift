// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NengaStudio",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NengaCore", targets: ["NengaCore"]),
        .executable(name: "NengaStudio", targets: ["NengaStudio"]),
    ],
    targets: [
        .target(name: "NengaCore"),
        .executableTarget(name: "NengaStudio", dependencies: ["NengaCore"]),
        .testTarget(name: "NengaCoreTests", dependencies: ["NengaCore"]),
    ],
    swiftLanguageModes: [.v6]
)
