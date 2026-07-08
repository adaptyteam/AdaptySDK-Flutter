# AdaptyRecipes-Flutter

Flutter recipes demo application for the local `adapty_flutter` SDK.

This app mirrors the iOS `AdaptyRecipes-SwiftUI` example:

- free and premium recipe categories;
- premium access check through the `premium` access level;
- modal and embedded Adapty Flow presentation;
- profile, login, logout, update, and restore actions.

Before running, replace the placeholders in `lib/app/app_constants.dart`:

```dart
static const adaptyApiKey = 'YOUR_API_KEY';
static const placementId = 'YOUR_PLACEMENT_ID';
```

Then run:

```sh
flutter pub get
flutter run
```
