// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "go2Ghostty",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "go2Ghostty", targets: ["go2Ghostty"])
    ],
    targets: [
        .executableTarget(
            name: "go2Ghostty",
            path: "Sources/go2Ghostty"
        )
    ]
)
