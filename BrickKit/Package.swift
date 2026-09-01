// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrickKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BrickKit", targets: ["BrickKit"])
    ],
    targets: [
        .target(name: "BrickKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "BrickKitTests", dependencies: ["BrickKit"], swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
