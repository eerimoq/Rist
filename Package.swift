// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rist",
    platforms: [
      .iOS(.v16),
      .macCatalyst(.v16)
    ],
    products: [
        .library(
            name: "Rist",
            targets: ["Rist", "librist"]),
    ],
    targets: [
        .target(name: "Rist", dependencies: ["librist"]),
        .binaryTarget(name: "librist",
                      url: "https://github.com/eerimoq/xcframeworks/releases/download/librist-0.2.20/librist.xcframework.zip",
                      checksum: "eee28fe337149f54a3047d6b100d601577ae64ae0cc3c7d43b684700048e02dd")
    ]
)
