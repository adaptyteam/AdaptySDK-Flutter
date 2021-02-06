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