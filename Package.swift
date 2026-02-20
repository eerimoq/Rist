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
            name: "Rist",
            targets: ["Rist", "librist"]),
    ],
    targets: [
        .target(name: "Rist", dependencies: ["librist"]),
        .binaryTarget(name: "librist",
                      url: "https://github.com/eerimoq/xcframeworks/releases/download/librist-0.3.0/librist.xcframework.zip",
                      checksum: "618e664d27af03eb4e88517a4767b0d284a405da9a06b1342c738227db0d81a6")
    ]
)
