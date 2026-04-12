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
                      url: "https://github.com/eerimoq/xcframeworks/releases/download/librist-0.3.1-1/librist.xcframework.zip",
                      checksum: "21089f909757d15b0b5a621677d1e0df38198db2897de47e673b1ce594c41947")
    ]
)
