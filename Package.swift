// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mlink",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mlink", targets: ["mlink"])
    ],
    targets: [
        .executableTarget(
            name: "mlink"
        ),
        .testTarget(
            name: "mlinkTests",
            dependencies: ["mlink"]
        )
    ]
)
