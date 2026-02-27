// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftmoji",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SwiftmojiCore"
        ),
        .executableTarget(
            name: "swiftmoji",
            dependencies: ["SwiftmojiCore"],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "swiftmojiTests",
            dependencies: ["SwiftmojiCore"]
        ),
    ]
)
