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
        // Temporarily tracking the iOS release/4.3.2 branch: this release needs the native 4.3.2 plugin, and
        // iOS 4.3.2 is not tagged yet. Pin back to `exact: "4.3.2"` before shipping — the Flutter bridge
        // (AdaptyPlugin) targets one exact native version and must not resolve to newer 4.x releases it
        // wasn't built against.
        .package(url: "https://github.com/adaptyteam/AdaptySDK-iOS.git", branch: "release/4.3.2"),
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
