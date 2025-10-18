// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftfulDataManagers",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftfulDataManagers",
            targets: ["SwiftfulDataManagers"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftfulThinking/IdentifiableByString.git", "1.0.0"..<"2.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftfulDataManagers",
            dependencies: [
                .product(name: "IdentifiableByString", package: "IdentifiableByString"),
            ]
        ),
        .testTarget(
            name: "SwiftfulDataManagersTests",
            dependencies: ["SwiftfulDataManagers"]
        ),
    ]
)
