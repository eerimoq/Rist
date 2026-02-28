// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rist",
    platforms: [
      .iOS(.v16),
      .macOS(.v13)
    ],
    products: [
        .library(
            name: "Rist",
            targets: ["Rist", "librist"]),
    ],
    targets: [
        .target(name: "Rist", dependencies: ["librist"]),
        .binaryTarget(name: "librist",
                      url: "https://github.com/eerimoq/xcframeworks/releases/download/librist-0.3.0-3/librist.xcframework.zip",
                      checksum: "6125d0c468e19c0c42420ba5305212c2e2328fb8ecd2859ca40ab498b81bb003")
    ]
)
