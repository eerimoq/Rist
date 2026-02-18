// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rist",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "librist",
            targets: ["librist"]
        ),
        .library(
            name: "Rist",
            targets: ["Rist", "librist"]),
    ],
    targets: [
        .target(name: "Rist", dependencies: ["librist"]),
        .binaryTarget(name: "librist",
                      url: "https://github.com/eerimoq/librist-xcframework/releases/download/v0.1.0/librist.xcframework.zip",
                      checksum: "1d2372bcb7b9dfcfbc3b534100a2ddf4f0416290ffbaf168f0b070065c192a6e")
    ]
)
