// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "adapty_flutter",
    platforms: [
        .iOS("15.0"),
    ],
    products: [
        .library(name: "adapty-flutter", targets: ["adapty_flutter"]),
    ],
    dependencies: [
        // Track the iOS SDK's dev branch during development; when pinning to a tagged release, use
        // `exact: "<version>"` (never `from:`) so the bridge can't resolve onto an untested newer 4.x.
        .package(url: "https://github.com/adaptyteam/AdaptySDK-iOS.git", branch: "dev"),
    ],
    targets: [
        .target(
            name: "adapty_flutter",
            dependencies: [
                .product(name: "Adapty", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyUI", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyPlugin", package: "AdaptySDK-iOS"),
            ],
            // Bridge sources are not Swift 6 strict-concurrency clean.
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
