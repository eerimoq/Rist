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
                      url: "https://github.com/eerimoq/librist-xcframework/releases/download/v0.2.0/librist.xcframework.zip",
                      checksum: "1f647a71203eb05ae34a6ca2333493c247b0141370c10ff70088d4dd34e42ff8")
    ]
)
