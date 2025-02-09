// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios-screen-capture",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "screencap", targets: ["Record"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
    ],
    targets: [
        .executableTarget(
            name: "Record",
            dependencies: [
                "USB",
                "ScreenCapture"
            ],
            path: "Sources/Record"
        ),
        .target(
            name: "ScreenCapture",
            dependencies: [
                "USB",
                "Packet",
                "Stream",
                "Util"
            ],
            path: "Sources/ScreenCapture",
            exclude: [
                "Object",
                "Packet",
                "Stream",
            ]
        ),
        .target(
            name: "USB",
            dependencies: [
                "Packet",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/USB"
        ),
        .target(
            name: "Packet",
            dependencies: [
                "Object",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/ScreenCapture/Packet"
        ),
        .target(
            name: "Object",
            dependencies: [
                "Util",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/ScreenCapture/Object"
        ),
        .target(
            name: "Stream",
            dependencies: [
                "Util",
                "Object"
            ],
            path: "Sources/ScreenCapture/Stream"
        ),
        .target(
            name: "Util",
            path: "Sources/Util"
        )
    ]
)
