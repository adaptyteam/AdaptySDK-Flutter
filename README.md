# Adapty Flutter SDK

![Adapty: Win back churned subscribers in your iOS app](https://raw.githubusercontent.com/adaptyteam/AdaptySDK-iOS/master/adapty.png)

## Requirements

iOS:
- iOS 9.0+
- Xcode 10.2+

Android:
- Android 4.1+

## Installation

Add Adapty as a project dependency in `pubspec.yaml`:
```yaml
dependencies:
    adapty_flutter:
        git:
            url: git@github.com:adaptyteam/AdaptySDK-Flutter.git
```

## Usage

### Configure your app

Add the following in your `main.dart`:

```dart
void main() async {
    await AdaptyFlutter.activate("PUBLIC_SDK_KEY",
          customerUserId: "YOUR_USER_ID");
    /* ... */
}
```
If your app doesn't have user IDs, you can use **`.activate("PUBLIC_SDK_KEY")`** or pass null for the **`customerUserId`**. Anyway, you can update **`customerUserId`** later within **`.identify()`** request.

Return **`true`** if success.

### Convert anonymous user to identifiable user

```dart
await AdaptyFlutter.identify("YOUR_USER_ID");
```

Return **`true`** if success.

### Observer mode

**`Not implemented`**

### Update customer profile

**`Not implemented`**

### Attribution tracker integration

To integrate with attribution system, just pass attribution you receive to Adapty method.

```dart
await AdaptyFlutter.updateAttribution(Map attribution, String source, {String userId});
```

**`attribution`** is **`Map`** object.
For **`source`** possible values are: **`AdaptyConstants.adjust`**, **`AdaptyConstants.appsflyer`** and **`AdaptyConstants.branch`**.

Return **`true`** if success.

### Get paywalls

```dart
await AdaptyFlutter.getPaywalls();
```
Return cached **`GetPaywallsResult`** model.

Listen **`getPaywallsResultStream`** to get paywalls whenever they change.

### Make purchase

```dart
await AdaptyFlutter.makePurchase(productId);
```
Return **`MakePurchaseResult`** model.

### Restore purchases

```dart
await AdaptyFlutter.restorePurchases();
```
Return **`AdaptyResult`** model.

### Validate purchase (Android)

```dart
await AdaptyFlutter.validatePurchase(purchaseType, productId, purchaseToken)
```

**`purchaseType`**, **`productId`** and **`purchaseToken`** are required and can't be empty.

Return **`AdaptyResult`** model.

### Validate receipt (iOS)

```dart
await AdaptyFlutter.validateReceipt(receipt)
```

**`receipt`** is required and can't be empty.

Return **`AdaptyResult`** model.

### Get user purchases info

**`Not implemented`**

### Get active purchases

```dart
await AdaptyFlutter.getActivePurchases(paidAccessLevel)
```

Return cached **`GetActivePurchasesResult`** model.

Listen **`getActivePurchasesResultStream`** to get active purchases whenever they change.

### Listening for purchaser info updates

Listen **`purchaserInfoUpdateStream`** for purchaser info updates.

Stream events model **`UpdatedPurchaserInfo`**

### Logout user

```dart
await AdaptyFlutter.logout();
```

Return **`true`** if success.

### Models
**`AdaptyResult`**:
| Name  | Description |
| -------- | ------------- |
| errorCode | Code of error. Null if the result is successful. |
| errorMessage | Error message. Null if the result is successful. |
| sucess() | Return true if the result is successful. |

**`AdaptyProduct`**:
| Name  | Description |
| -------- | ------------- |
| id | Identifier of the product in vendor system (App Store/Google Play etc.). |
| title | The name of the product. |
| description | A description of the product. |
| price | The cost of the product in the local currency. |
| localizedPrice | Localized price of the product. |
| currency | Product locale currency. |

**`GetPaywallsResult`**:
| Name  | Description |
| -------- | ------------- |
| paywalls | List of Adapty paywalls id's. |
| products | List of Adapty Product's. |

**`MakePurchaseResult`**:
| Name  | Description |
| -------- | ------------- |
| purchaseToken | Android purchase token. |
| purchaseType | Android purchase type |
| receipt | iOS receipt of purchase |

**`GetActivePurchasesResult`**:
| Name  | Description |
| -------- | ------------- |
| activeSubscription | True if user has an active active subscription. |
| nonSubscriptionsProductIds | List of active non subscription products id's. |
| activeSubscriptionProductId | Identifier of active subscription in vendor system (App Store/Google Play etc.).|

**`UpdatedPurchaserInfo`**:
| Name  | Description |
| -------- | ------------- |
| nonSubscriptionsProductIds | List of active non subscription products id's. |
| activePaidAccessLevels | List of active paid access levels id's. |
| activeSubscriptionsIds | List of active subscription products id's. |

## License

Adapty is available under the MIT license.
