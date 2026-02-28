// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftmoji",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftmojiCore", targets: ["SwiftmojiCore"]),
    ],
    targets: [
        .target(
            name: "SwiftmojiCore",
            resources: [
                .copy("Resources/emoji-test.txt"),
                .copy("Resources/kaomoji-lib.json"),
                .copy("Resources/kaomoji-ordered.json"),
            ]
        ),
        .testTarget(
            name: "swiftmojiTests",
            dependencies: ["SwiftmojiCore"]
        ),
    ]
)
