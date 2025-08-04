// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Weatherspoon",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "Weatherspoon", targets: ["WeatherspoonApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "WeatherspoonCore",
            dependencies: []),
        .target(
            name: "WeatherspoonApp",
            dependencies: ["WeatherspoonCore"]),
        .testTarget(
            name: "WeatherspoonTests",
            dependencies: ["WeatherspoonCore"]),
    ]
)
