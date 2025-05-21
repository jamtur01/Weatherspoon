// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Weatherspoon",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "Weatherspoon", targets: ["Weatherspoon"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Weatherspoon",
            dependencies: []),
    ]
)
