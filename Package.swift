// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SkyWallpaper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SkyCore", targets: ["SkyCore"]),
        .executable(name: "SkyWallpaper", targets: ["SkyApp"])
    ],
    targets: [
        .target(
            name: "SkyCore",
            path: "Sources/SkyCore"
        ),
        .executableTarget(
            name: "SkyApp",
            dependencies: ["SkyCore"],
            path: "Sources/SkyApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "SkyCoreTests",
            dependencies: ["SkyCore"],
            path: "Tests/SkyCoreTests"
        )
    ]
)
