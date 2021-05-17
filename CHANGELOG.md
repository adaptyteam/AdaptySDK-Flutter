# 1.0.0-nullsafety.0

* Enable null safety
* Require Dart 2.12 or greater.
# 0.3.5

* [iOS] Added `isFamilyShareable` property to product for iOS 14+.
* [iOS] Added `.presentCodeRedemptionSheet()` to public SDK API

# 0.3.4

* [Android] Small fix in requests

# 0.3.3

* [iOS] Added retry for `createProfile` request in case of poor connection or if server is down.
* [Android] Added gzip support
* Removed unnecessary event channel invocations for `.getPaywalls()` and `.getPurchaserInfo()` methods

# 0.3.2

* Fixed `.getPaywalls()` callback without an internet connection (Android only)

# 0.3.1

* Added `.setFacebookAnonymousId` method to `AdaptyProfileParameterBuilder`
* Added `freeTrialPeriod` property of `AdaptyProduct` model (Android only)

# 0.3.0

* Added ability to connect observer mode purchase with a paywall it was made from using `.setTransactionVariationId` method
* Added ability to opt-out from external analytics services using `.setExternalAnalyticsEnabled` method
* Added public `abTestName` and `name` properties to `AdaptyPaywall` and to nested products array.
* Paywall views must be reported using `.logShowPaywall(paywall)` method from now on, otherwise, views will not be collected.

# 0.2.0

* Plugin initialization scheme changed to prevent missing transaction on iOS.
* Added `.logShowPaywall(paywall)` to manually record paywall show event.
* Added `apnsTokenString` to public properties.
* Removed `state` from `.getPurchaserInfo()` callback. Added `forceUpdate` as an optional request parameter.
* Removed `state` from `.getPaywalls()` callback. Added `forceUpdate` as an optional request parameter.

# 0.1.2

* empty string custom payload fixed
* `updateAttribution()` fixed on Android
* `getPurchaserInfo()` stability improved
* `verbose logLevel` removed as default

# 0.1.1

* `customPayloadString` added to Paywall
* birthday fix in `updateProfile`

# 0.1.0

* Initial release