// swift-tools-version: 6.2
import PackageDescription

// adapty_flutter_kids — generated. Identical Swift bridge sources as adapty_flutter; the ONLY
// difference is the `KidsMode` trait enabled on AdaptySDK-iOS (IDFA / AdSupport compiled out).
let package = Package(
    name: "adapty_flutter_kids",
    platforms: [
        .iOS("15.0"),
    ],
    products: [
        .library(name: "adapty-flutter-kids", targets: ["adapty_flutter_kids"]),
    ],
    dependencies: [
        // Track the iOS 4.0 release branch during development; when pinning to a tagged release, use
        // `exact: "4.0.0"` (never `from:`) so the bridge can't resolve onto an untested newer 4.x.
        .package(
            url: "https://github.com/adaptyteam/AdaptySDK-iOS.git",
            branch: "release/4.0.0",
            traits: ["KidsMode"]
        ),
    ],
    targets: [
        .target(
            name: "adapty_flutter_kids",
            dependencies: [
                .product(name: "Adapty", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyUI", package: "AdaptySDK-iOS"),
                .product(name: "AdaptyPlugin", package: "AdaptySDK-iOS"),
            ],
            path: "Sources/adapty_flutter",          // copied bridge sources, dir not renamed
            swiftSettings: [.swiftLanguageMode(.v5)] // bridge not strict-concurrency clean
        ),
    ]
)
