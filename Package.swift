// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DevPorts",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DevPorts", path: "Sources/DevPorts")
    ]
)
