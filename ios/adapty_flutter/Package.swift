// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "adapty_flutter",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "adapty-flutter", targets: ["adapty_flutter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/adaptyteam/AdaptySDK-iOS.git", exact: "3.17.2"),
    ],
    targets: [
        .target(
            name: "adapty_flutter",
            dependencies: [
                .product(name: "Adapty", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyUI", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyPlugin", package: "AdaptySDK-iOS"),
            ],
            // Match the CocoaPods podspec (`s.swift_version = '5.9'`). The plugin
            // sources are not Swift 6 strict-concurrency clean; both integration
            // paths must compile under the same language mode.
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
