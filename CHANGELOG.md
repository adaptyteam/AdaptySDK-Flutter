# 2.2.4

- [iOS] Fixed `didUpdateProfileStream` serialization bug.

# 2.2.3

- Added integration with Firebase and Google Analytics. [Read more.](https://docs.adapty.io/docs/firebase-and-google-analytics)
- [Android] Fixed a bug when products returned in a wrong order

# 2.2.2

- [iOS] Fixed a bug when some additional purchase parameters were not sent in Observer Mode.

# 2.2.1

- [Android] fixed parsing error for free trial fields.
- Updated errors documentation.

# 2.2.0

Meet the second version of the Adapty SDK 🎉

See our [What's new in Adapty Flutter SDK 2.0 doc](https://docs.adapty.io/v2.0/docs/migration-to-flutter-2) for API updates.
Adapty 2.0 introduces the following updates:

## Breaking changes:

- Adapty now is singleton. Use `Adapty().someMethodCall()` instead of `Adapty.someMethodCall()`
- User-initiated purchases are now automatically processed by the system, so we have removed the `deferredPurchasesStream` and `makeDeferredPurchase()` method.
- We are no longer support Visual Paywalls and Promo Campaigns features, so you should remove the calls to the corresponding methods, if there were any
- Instead of getting all paywalls in one request with the `.getPaywalls()`, it must be done separately for each paywall using `.getPaywall(id:)`
- Products are no longer part of the paywall, they must be loaded separately with `.getPaywallProducts(paywall:)`
- It is no longer possible to use products outside of the paywall. If you need to handle a product, create a separate paywall for it (or for multiple products).
- `introductoryOfferEligibility` – instead of true/false we give a more extended list of options
- The `AdaptyProfileParametersBuilder` is redesigned:
  - Methods, related to custom attributes now can throw an exception, if key or value didn't pass validation
  - Added an option to pass null values to builder functions for more convenience
  - You can now remove customAttributes with the function `.removeCustomAttribute("key")`
  - You have to use `.build()` method and pass resulting `AdaptyProfileParameters` object to `.updateProfile` method
- `.setAnalyticsDisabled()` method has been eliminated. Use the `.setAnalyticsDisabled` method of `AdaptyProfileParametersBuilder`.
- The `forceUpdate` parameter was removed from the `getPaywall` method. The result will always be up to date if it is possible to retrieve data from the server

## Renames

- `PurchaserInfo` renamed to `AdaptyProfile`
- `.getPurchaserInfo` renamed to `.getProfile`
- `didReceivePurchaserInfoStream` was also renamed to `.didUpdateProfileStream`
- `developerId` field of `AdaptyPaywall` was renamed to `id`
- `AdaptyAttributionNetwork` renamed to `AdaptyAttributionSource`

## Fixes

- Fixed wrong behavior of fallback paywalls in some cases
- `.setFallbackPaywalls()` method now does not return errors related to StoreKit product retrieval
- Incorrect user segmentation in some rare cases

## Additions:

- Ability to log onboard screens with `.logShowOnboarding()`. [Read more](https://docs.adapty.io/docs/onboarding-screens-tracking)
- Added ability to get previously set `customAttributes`, now it is part of `AdaptyProfile`

## Under the hood:

- The server interaction layer was rewritten from scratch.
- The initial request sequence has been optimized and simplified
- Reduced the number of API calls made by SDK. Some of the request are now faster and transfer less data.
- Independent requests can be executed simultaneously
- StoreKit interaction layer was refactored

Full documentation can be found in [here](https://docs.adapty.io/v2.0/docs/).

# 1.0.14

- Fixed type cast in the `makeDeferredPurchase` method

# 1.0.13

- Upgraded with iOS SDK version 1.17.7 and Android SDK version 1.11.0

# 1.0.12

- [Android] fixed localized properties

# 1.0.11

- Support for Flutter 3.0

# 1.0.10

- Ability to use Adapty-Info.plist for storing initialization parameters

# 1.0.9

- The `getPromo` method now works for Android [Issue 34](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/34)
- Fixed typo in word "deferred" [Issue 35](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/35)

# 1.0.8

- Updated `PurchaserInfoModel` property `profileId` access level to public

# 1.0.7

- [iOS] Added support for disabling IDFA collection
- [Android] Improved handling clicks on push notifications

# 1.0.6

- [iOS] Added support for AdServices attribution tracking
- [Android] internal sdk improvements

# 1.0.5

- [Android] added logLevel ALL, logLevel VERBOSE doesn't include analytical logs, but ALL does
- changed example for updating custom attribution
- various improvements

# 1.0.4

- added toString for `AdaptyAccessLevelInfo`, `AdaptySubscriptionInfo`, `AdaptyNonSubscriptionInfo` models

# 1.0.3

- Added new log level "all"
- Fallback paywalls offline work
- [iOS] Added optional `offerId` parameter to `makePurchase` method

# 1.0.2

- [iOS] Updated AdaptyProfileParameterBuilder to work with ATTrackingManager.AuthorizationStatus
- Removed usage of dart ffi
- Made receipt validation api method private

# 1.0.1

- [Android] Added support for fallback paywalls

# 1.0.0

- Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

# 1.0.0-nullsafety.0

- Enable null safety
- Require Dart 2.12 or greater.

# 0.3.6

- [Android] fixed localizedTitle in product

# 0.3.5

- [iOS] Added `isFamilyShareable` property to product for iOS 14+.
- [iOS] Added `.presentCodeRedemptionSheet()` to public SDK API

# 0.3.4

- [Android] Small fix in requests

# 0.3.3

- [iOS] Added retry for `createProfile` request in case of poor connection or if server is down.
- [Android] Added gzip support
- Removed unnecessary event channel invocations for `.getPaywalls()` and `.getPurchaserInfo()` methods

# 0.3.2

- Fixed `.getPaywalls()` callback without an internet connection (Android only)

# 0.3.1

- Added `.setFacebookAnonymousId` method to `AdaptyProfileParameterBuilder`
- Added `freeTrialPeriod` property of `AdaptyProduct` model (Android only)

# 0.3.0

- Added ability to connect observer mode purchase with a paywall it was made from using `.setTransactionVariationId` method
- Added ability to opt-out from external analytics services using `.setExternalAnalyticsEnabled` method
- Added public `abTestName` and `name` properties to `AdaptyPaywall` and to nested products array.
- Paywall views must be reported using `.logShowPaywall(paywall)` method from now on, otherwise, views will not be collected.

# 0.2.0

- Plugin initialization scheme changed to prevent missing transaction on iOS.
- Added `.logShowPaywall(paywall)` to manually record paywall show event.
- Added `apnsTokenString` to public properties.
- Removed `state` from `.getPurchaserInfo()` callback. Added `forceUpdate` as an optional request parameter.
- Removed `state` from `.getPaywalls()` callback. Added `forceUpdate` as an optional request parameter.

# 0.1.2

- empty string custom payload fixed
- `updateAttribution()` fixed on Android
- `getPurchaserInfo()` stability improved
- `verbose logLevel` removed as default

# 0.1.1

- `customPayloadString` added to Paywall
- birthday fix in `updateProfile`

# 0.1.0

- Initial release
