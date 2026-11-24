<h1 align="center" style="border-bottom: none">
<b>
    <a href="https://adapty.io/?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter">
        <img src="https://adapty-portal-media-production.s3.amazonaws.com/github/logo-adapty-new.svg">
    </a>
</b>
<br>Easy In-App Purchases Integration to
<br>Make Your Flutter App Profitable
</h1>

<p align="center">
<a href="https://go.adapty.io/subhub-community-flutter-rep"><img src="https://img.shields.io/badge/Adapty-discord-purple"></a>
<a href="https://github.com/adaptyteam/AdaptySDK-Flutter/blob/master/LICENSE"><img src="https://img.shields.io/badge/license-MIT-brightgreen.svg"></a>
</p>


<p align="center">
    <a href="https://adapty.io?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter"><b>Website</b></a> •
    <a href="https://go.adapty.io/subhub-community-flutter-rep"><b>Discord</b></a> •
    <a href="https://twitter.com/AdaptyTeam"><b>Twitter</b></a>
</p>

![Adapty: CRM for mobile apps with subscriptions](https://adapty-portal-media-production.s3.amazonaws.com/github/adapty-schema.png)

Adapty SDK is an open-source framework that makes implementing in-app subscriptions in Flutter fast and easy. It’s 100% open-source, native and lightweight.

## Why Adapty?

- [No server code implementation](https://adapty.io/docs/sdk-installation-flutter?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter). Integrate in-app purchases with server-side receipt validation in minutes — in your own paywall or using the no-code flow builder.
- [No-code flow builder](https://adapty.io/docs/adapty-flow-builder?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter). Create beautiful, natively rendered single- or multi-screen flows in the no-code editor and display them in your app. With flows, you can start getting paid instantly or implement engaging onboardings in your app.
- [On-the-fly paywalls price testing](https://adapty.io/docs/ab-tests?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter). Test different prices, duration, offers, messages, and designs simultaneously, all without new app releases.
- [Full customer's payment history](https://adapty.io/docs/profiles-crm?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter). Explore the user's payment events from the trial start to subscription cancellation or billing issues.
- [3rd-party integrations](https://adapty.io/docs/events?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter). Send subscription events to 3rd-party analytics, attribution, and ad services with no coding, even if the user uninstalls the app.
- [Advanced analytics](https://adapty.io/docs/charts?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter). Analyze your app real-time metrics with advanced filters, such as Ad network, Ad campaign, country, A/B test, etc.

<h3 align="center" style="border-bottom: none; margin-top: -15px; margin-bottom: -15px; font-size: 150%">
<a href="https://adapty.io/schedule-demo?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter_schedule-demo">Talk to Us to Learn More</a>
</h3>

## Integrate IAPs within a few hours without server coding

**Adapty handles everything, from free trials to refunds, in a simple, developer-friendly SDK.**

- Free trials, upgrades, downgrades, crossgrades, family sharing, renewals, promo offers, intro offers, promo codes, and more – Adapty SDK does everything with a single line of code.
- Easy subscription management.
- One-time purchases and lifetime subscriptions supported.
- Sync subscribers' states across iOS, Android, and Web.

## Design flows in the no-code Flow Builder

![No-code Flow Builder](https://adapty-portal-media-production.s3.amazonaws.com/github/flow-cover.webp)

With the [Adapty Flow Builder](https://adapty.io/docs/adapty-flow-builder?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter), you can visually design complete user experiences — from single-screen paywalls to multi-step onboardings, surveys, and quizzes.

- **Flexible customizable flows**: Build any kind of flow: a single-screen paywall, a multi-step sequence, a survey, or anything in between.
- **Native rendering**: The Adapty SDK renders flows natively without web views to ensure a seamless user experience.
- **Update without redeploying**: Change copy, design, pricing, or logic any time. Updates reach your users without an app release.

Adapty automatically renders your flow and handles all the complex purchase logic, receipt validation, and subscription management behind the scenes.

## Test paywalls & prices on Flutter without app releases

![Adapty: In-app subscriptions with paywall A/B testing](https://adapty-portal-media-production.s3.amazonaws.com/github/ab-test-new.png)

- Optimize in-app subscriptions with the paywall A/B testing. Conversions, trials, revenue, cancellations, and more — everything is calculated for you: each paywall and each A/B test.
- Change images, colors, layouts, and literally anything using the no-code builder or a custom JSON. Configure different prices, trial periods, promo offers, and more in Adapty without app releases.

## Real-time analytics for your Flutter app

![Adapty: How Adapty works](https://adapty-portal-media-production.s3.amazonaws.com/github/analyticss.gif)

- Manage the subscription's state without managing transactions.
- 99.5% accuracy.
- View and analyze data by attributes, such as status, channels, campaigns, and more.
- Filter, group, and measure metrics by attribution, platform, custom users' segments, and more in a few clicks.

## Mobile app monetization's largest community

Ask questions, participate in discussions about Adapty-related topics, become a part of our community for app developers and marketers. Learn how to monetize your app, ask questions, post jobs, read industry news and analytics. Ad free.

<a href="https://discord.gg/subscriptions-hub"><img src="https://adapty-portal-media-production.s3.amazonaws.com/github/join-discord.svg" /></a>

## Get started

Follow our [quickstart guide](https://adapty.io/docs/flutter-sdk-overview?utm_source=github&utm_medium=referral&utm_campaign=AdaptySDK-Flutter#get-started) to install and configure Adapty SDK. Set up purchases in hours instead of weeks 🚀

## Requirements

| Requirement | Minimum |
|---|---|
| Flutter | 3.32.0 |
| Dart | 3.8.0 |
| iOS | 15.0 |
| iOS, for flows | 16.0 |
| Xcode | 26.0 |
| Android | API 21 (Android 5.0) |

> **iOS uses Swift Package Manager.** As of 4.0.0 the iOS native SDK is distributed via Swift Package Manager only (CocoaPods support was dropped). On **Flutter 3.44+** SwiftPM is enabled by default and the plugin works out of the box. On **Flutter 3.32–3.43** you must enable it once per project before building for iOS:
>
> ```sh
> flutter config --enable-swift-package-manager
> ```

> **Flows require iOS 16.** Below iOS 16, `AdaptyUI().createFlowView()` fails with `AdaptyErrorCode.platformNotSupported`, and `AdaptyUIFlowPlatformView` stays empty and reports that error to its `onDidReceiveError` and to `flowViewDidReceiveError` of your flows events observer. Check for this code and show your own content on those devices. Onboardings and the rest of the SDK support iOS 15.

## Custom elements

Flows can contain custom elements that your app draws with native views. Register a resolver in native code, in Swift on iOS and in Kotlin on Android, once at launch. Every flow uses it, including one shown by `AdaptyUIFlowPlatformView`: there is no resolver for a single flow. Custom elements can't be drawn with Flutter widgets.

The resolver gets the custom type and ID of each custom element. Return a view for the types your app draws and `nil` on iOS or `null` on Android for the rest. An element the resolver does not draw, and every element when no resolver is registered, shows the fallback set for it in the Adapty Flow Builder; without a fallback, nothing is drawn in its place. The resolver is called again each time the flow updates the element, so keep it cheap and keep heavy state in your views.

### iOS

In `ios/Runner/AppDelegate.swift`, import `AdaptyUI` and `AdaptyUIBuilder` and register the resolver with `AdaptyUI.setCustomElementsResolver` in `application(_:didFinishLaunchingWithOptions:)`; if your `AppDelegate` already overrides it, add the call there. If Xcode can't find these modules, add the AdaptySDK-iOS package to the Runner target at the iOS version that the CHANGELOG lists for this release.

```swift
import AdaptyUI
import AdaptyUIBuilder
import SwiftUI

// In your AppDelegate:
override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  AdaptyUI.setCustomElementsResolver(ExampleCustomElements())
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}

// Draws the custom elements of type `example_badge`; any other type shows its fallback.
@MainActor
struct ExampleCustomElements: AdaptyUICustomElementsResolver {
  func view(forType type: String, id: String, context: AdaptyUICustomElementContext) -> AnyView? {
    switch type {
    case "example_badge":
      return AnyView(Text("Drawn by the app: \(id)"))
    default:
      return nil
    }
  }
}
```

### Android

Add `io.adapty:android-ui` without a version to the dependencies of the module that depends on this package, usually `app`, and write the resolver in that module: this package provides the version to it, and in another module the dependency can't be resolved without a version. Don't add the Adapty BOM (`io.adapty:adapty-bom`) or a version of your own: a newer `android-ui` than this package's can break flows at runtime.

```kotlin
// android/app/build.gradle.kts
dependencies {
    implementation("io.adapty:android-ui")
}
```

In a Groovy `android/app/build.gradle`, the line is `implementation 'io.adapty:android-ui'`.

Register the resolver in `Application.onCreate`. If your app has no `Application` subclass yet, add one and name it in `android:name` of the `<application>` tag in `AndroidManifest.xml`, in place of `${applicationName}`.

```kotlin
import android.app.Application
import android.widget.TextView
import com.adapty.ui.AdaptyCustomElementContent
import com.adapty.ui.AdaptyCustomElementsResolver
import com.adapty.ui.AdaptyUI

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Draws the custom elements of type `example_badge`; any other type shows its fallback.
        AdaptyUI.setCustomElementsResolver(
            AdaptyCustomElementsResolver { type, id ->
                if (type == "example_badge") {
                    AdaptyCustomElementContent.view(factory = { context, _ ->
                        TextView(context).apply { text = "Drawn by the app: $id" }
                    })
                } else {
                    null
                }
            }
        )
    }
}
```

The [example app](example/README.md) registers this resolver on both platforms.

## Example app

This repository includes a sample application that demonstrates Adapty SDK integration. See the [example app](example/README.md) and run it.

## Contributing

- Feel free to open an issue, we check all of them or drop us an email at [support@adapty.io](mailto:support@adapty.io) and tell us everything you want.
- Want to suggest a feature? Just contact us or open an issue in the repo.

## Like Adapty SDK?

So do we! Feel free to star the repo ⭐️⭐️⭐️ and make our developers happy!

## License

Adapty is available under the MIT license. [Click here](https://github.com/adaptyteam/AdaptySDK-Flutter/blob/master/LICENSE) for details.
