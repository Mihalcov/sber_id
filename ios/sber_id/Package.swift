// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sber_id",
    platforms: [
        .iOS("14.0"),
    ],
    products: [
        .library(name: "sber-id", targets: ["sber_id"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/sid-sdk/SIDSDK", from: "1.7.4"),
    ],
    targets: [
        .target(
            name: "sber_id",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "SIDSDK", package: "SIDSDK"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
