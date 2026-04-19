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
                      url: "https://github.com/eerimoq/xcframeworks/releases/download/librist-0.2.13/librist.xcframework.zip",
                      checksum: "df5a77089cd566f5e75dd7f3905ec6d2c9d0e44291e2d30846b290383ae248d1")
    ]
)
