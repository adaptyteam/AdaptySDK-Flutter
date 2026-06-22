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
        // Dev: track the in-progress branch. Ship: `from: "4.0.0"` once tagged.
        .package(
            url: "https://github.com/adaptyteam/AdaptySDK-iOS.git",
            branch: "feature/crossplatform-4",
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
