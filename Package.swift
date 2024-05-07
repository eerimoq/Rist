// swift-tools-version: 5.10
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
        .target(
          name: "librist",
          dependencies: [],
          exclude: [
          ],
          sources: [
            "src/flow.c",
            "src/libevsocket.c",
            "src/logging.c",
            "src/mpegts.c",
            "src/network.c",
            "src/peer.c",
            "src/rist-common.c",
            "src/rist-thread.c",
            "src/rist.c",
            "src/rist_ref.c",
            "src/udp.c",
            "src/udpsocket.c",
            "src/crypto/crypto.c",
            "src/crypto/psk.c",
            "src/crypto/random.c",
            "src/crypto/srp_constants.c",
            "src/proto/eap.c",
            "src/proto/gre.c",
            "src/proto/rist_time.c",
            "src/proto/rtp.c",
          ],
          cSettings: [
            .headerSearchPath("src"),
            .headerSearchPath("."),
            .headerSearchPath("include/librist"),
            .headerSearchPath("contrib/mbedtls/include"),
            .headerSearchPath("contrib"),
          ]
        ),


    ]
)
