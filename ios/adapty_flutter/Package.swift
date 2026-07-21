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
        // Pin the reviewed iOS integration revision; replace it with an exact tag at release cut.
        .package(
            url: "https://github.com/adaptyteam/AdaptySDK-iOS.git",
            revision: "468c8fd9ad2f89956f108e84868a0176f29bbd74"
        ),
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
