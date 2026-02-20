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
                      checksum: "8166f4a8f3c5840e650c20c8d77bdc79125b800071a457a252bde0610ca622bc")
    ]
)
