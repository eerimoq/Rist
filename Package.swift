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
                      url: "https://github.com/eerimoq/Rist/releases/download/v0.3.0/librist.xcframework.zip",
                      checksum: "3a7ad76b2b6b80bc05800884f371ff8947801e597555e361050cbdcf6a8e1814")
    ]
)
