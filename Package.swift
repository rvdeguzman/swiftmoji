// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftmoji",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "swiftmoji",
            exclude: ["Info.plist"]
        ),
    ]
)
