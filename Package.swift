// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Panorama",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Panorama", targets: ["Panorama"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "PanoramaCore"),
        .target(name: "TrackpadBridge", publicHeadersPath: "include", linkerSettings: [.linkedFramework("CoreFoundation")]),
        .executableTarget(name: "Panorama", dependencies: ["PanoramaCore", "TrackpadBridge", .product(name: "Sparkle", package: "Sparkle")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "PanoramaCoreTests", dependencies: ["PanoramaCore"])
    ]
)
