# Adapty Recipes

Flutter recipes demo application for the local `adapty_flutter` SDK.

This app mirrors the iOS `AdaptyRecipes-SwiftUI` example:

- free and premium recipe categories;
- premium access check through the `premium` access level;
- modal and embedded Adapty Flow presentation, with the flow locale editable on the profile screen;
- profile, login, logout, update, and restore actions;
- an external attribution demo (`Send External Attribution` on the profile screen).

Before running, replace the placeholders in `lib/app/app_constants.dart`:

```dart
static const adaptyApiKey = 'YOUR_API_KEY';
static const placementId = 'YOUR_PLACEMENT_ID';
```

`flowLocale` in the same file is the initial locale for flow views (`null` = default); change it there or from the profile screen at runtime.

Then run:

```sh
flutter pub get
flutter run
```
