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
        // Temporarily tracking the iOS release/4.5.0 branch: the flow localization strategies and the
        // host localization resolver ship in iOS 4.5.0, which is not tagged yet. Pin back to
        // `exact: "4.5.0"` before shipping — the Flutter bridge (AdaptyPlugin) targets one exact native
        // version and must not resolve to newer 4.x releases it wasn't built against.
        .package(
            url: "https://github.com/adaptyteam/AdaptySDK-iOS.git",
            branch: "release/4.5.0",
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
