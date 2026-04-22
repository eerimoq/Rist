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
                      url: "https://github.com/eerimoq/xcframeworks/releases/download/librist-0.2.13-1/librist.xcframework.zip",
                      checksum: "b4e23bd53924295a130b81a11c13118942a6a944f22d6084a8d031356828c6c9")
    ]
)
