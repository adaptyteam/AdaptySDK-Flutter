# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

Adapty Flutter SDK (`adapty_flutter`) — a Flutter plugin for in-app subscriptions, paywalls, and onboardings via Adapty's backend. Supports iOS (15.0+) and Android (SDK 21+).

## Common Commands

```bash
# Analyze SDK/tool code and the example package
flutter analyze lib tool test
cd example && flutter analyze

# Run tests
flutter test
cd example && flutter test

# Get dependencies
flutter pub get
cd example && flutter pub get

# Build example app
cd example && flutter build ios --no-codesign
cd example && flutter build apk
```

CI is `.github/workflows/ci.yml` (Linux: analyze + test for the root package and for the example). There is no custom Makefile or lint script in this repo. The linting config is minimal — `analysis_options.yaml` sets max line length to 120.

## Architecture

### Plugin Structure (Method Channel)

The SDK is a standard Flutter plugin using **MethodChannel** (`flutter.adapty.com/adapty`) for Dart↔Native communication:

- **Dart side:** `lib/src/adapty.dart` — singleton `Adapty` class with all public API methods. `AdaptyUI` is defined via `part 'adaptyui.dart'` in the same library.
- **Android side:** `android/src/main/kotlin/com/adapty/flutter/AdaptyFlutterPlugin.kt` — bridges to the native Android Adapty SDK (dependency via BOM in `android/build.gradle`).
- **iOS side:** `ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyFlutterPlugin.swift` — bridges to the native iOS Adapty SDK (dependency via Swift Package Manager in `ios/adapty_flutter/Package.swift`). iOS is SPM-only as of 4.0.0 (no podspec).

All method names and argument keys are centralized in `lib/src/constants/method.dart` and `lib/src/constants/argument.dart`.

### Cross-Platform Protocol

`cross_platform.yaml` (root) is a JSON Schema defining the request/response contract between Dart and native code. When adding or changing a method, this schema should stay in sync.

### Models & Serialization

All data models live in `lib/src/models/`. Each model has a corresponding `*JSONBuilder` in `lib/src/models/private/` that handles JSON serialization/deserialization. The base helpers (`Map<String, dynamic>` extensions for typed access) are in `lib/src/models/private/json_builder.dart`.

Public exports are controlled via `lib/adapty_flutter.dart` using explicit `show` clauses.

### Event System

Observer interfaces (`AdaptyUIFlowsEventsObserver`, `AdaptyUIOnboardingsEventsObserver`) in `lib/src/adaptyui_observer.dart` handle native→Dart callbacks. Event routing goes through `lib/src/adaptyui_events_proxy.dart`. Profile updates use a broadcast `StreamController`.

### Platform Views

Native paywall and onboarding views are embedded via `PlatformView` widgets in `lib/src/platform_views/`. Corresponding native view factories are in the Android/iOS directories.

## Key Patterns

- **Singletons:** `Adapty()` and `AdaptyUI()` are singleton factories.
- **Builders:** Configuration objects use the builder pattern (`AdaptyConfigurationBuilder`, `AdaptyProfileParametersBuilder`, `AdaptyPurchaseParametersBuilder`).
- **JSON round-trip:** Native calls return `Map<String, dynamic>` decoded from JSON. Models are constructed from these maps via their JSON builders; outgoing data uses `jsonValue` getters.

## Git Conventions

- Use conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, etc.
- Do not add "Co-Authored-By" lines to commit messages.

## Public Documentation

Dartdoc in `lib/`, the README and the changelog are the published API reference. Write them for a
reader who has this package as a dependency and nothing else: our repository, our branches, our
tickets and our build do not exist for them.

Before documenting a caveat, ask what the reader would do differently after reading it. If the
answer is nothing, it is not documentation — it is a note to ourselves, and it belongs in the
commit message or in this file.

That test rules out the native dependency versions in particular. They are pinned in
`android/build.gradle` and `ios/adapty_flutter/Package.swift`, so a reader can neither choose nor
override them; a parameter never "needs native SDK X.Y", it simply works or does not work in the
version of this package they installed. Document the behaviour this version ships. A changelog
entry may state that a pin was bumped and what changed for the reader because of it — the
reasoning behind the bump is ours, not theirs.

The versions that do belong in the docs are the ones the reader picks: the Flutter and Dart
constraints, the iOS deployment target, `minSdk`, and the version of this package a feature
first appeared in.

## Version Coordination

Version bumps require updating multiple files in lockstep:

- `pubspec.yaml` — Dart package version
- `lib/src/adapty_version.dart` — `adaptySDKVersion`, reported to the backend and exposed as `Adapty.sdkVersion`. Easy to miss: it rarely conflicts on merge, so a stale value survives silently (4.0.1 shipped reporting itself as 4.0.0).
- `android/build.gradle` — Android native SDK BOM version and crossplatform version
- `ios/adapty_flutter/Package.swift` — iOS native SDK dependency (SPM; pin moves in lockstep)
- `tool/kids/Package.swift` — the same iOS pin for the generated `adapty_flutter_kids` variant; keep it identical to `ios/adapty_flutter/Package.swift` apart from the `KidsMode` trait
- `CHANGELOG.md`
- `pubspec.yaml` `publish_to: none` — present on development (`-dev.N`) versions; remove it at the release cut, together with the version bump.
