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

# Check the public API (needs `dart pub global activate dart_apitool 0.23.2` and network access)
dart run tool/api/check_api.dart            # snapshot + comparison with the last release on pub.dev
dart run tool/api/check_api.dart --offline  # snapshot only
dart run tool/api/check_api.dart --update   # rewrite tool/api/public_api.json after an intended API change

# Build the integration test app, which hosts the real plugin for integration tests on a simulator and an emulator.
# It enables Swift Package Manager in its own pubspec, so it does not depend on the global Flutter setting.
cd integration_test_app && flutter pub get && flutter analyze
cd integration_test_app && flutter build apk --debug
# iOS: build for one named simulator; `flutter build ios --simulator` fails with Xcode 27 (it builds two architectures).
# Keep FLUTTER_TARGET: after any `flutter test` on iOS, ios/Flutter/Generated.xcconfig still points at a deleted
# temporary test entry point, and xcodebuild fails without the override.
cd integration_test_app/ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination 'platform=iOS Simulator,name=<simulator>' -derivedDataPath <dir> \
  FLUTTER_TARGET=lib/main.dart COMPILER_INDEX_STORE_ENABLE=NO build

# Run the JVM unit tests of the Android plugin (android/src/test) through the example app's Gradle project (needs JDK 17+)
cd example && flutter pub get && flutter build apk --config-only && cd android && ./gradlew :adapty_flutter:testDebugUnitTest
```

The Android unit tests passed only if `example/build/adapty_flutter/test-results/testDebugUnitTest/TEST-*.xml` exist and report `tests` greater than 0 with `failures="0"`. `BUILD SUCCESSFUL` alone proves nothing: when Gradle finds no test sources (for example, `pub get` was run in another checkout, so `.flutter-plugins-dependencies` points the example at another copy of the plugin), the task is `NO-SOURCE` and the build still succeeds.

CI is `.github/workflows/ci.yml` (Linux: analyze + test for the root package and for the example, the public API check against `tool/api/public_api.json`, and the JVM unit tests of the Android plugin). There is no custom Makefile or lint script in this repo. The linting config is minimal — `analysis_options.yaml` sets max line length to 120.

## Architecture

### Plugin Structure (Method Channel)

The SDK is a standard Flutter plugin using **MethodChannel** (`flutter.adapty.com/adapty`) for Dart↔Native communication:

- **Dart side:** `lib/src/adapty.dart` — singleton `Adapty` class with all public API methods. `AdaptyUI` is defined via `part 'adaptyui.dart'` in the same library.
- **Runtime:** `lib/src/runtime/` — `AdaptyRuntime` holds the transport over the channel and the state the SDK keeps. The call to the native side and the reading of its reply are in `bridge.dart` (`adaptyInvoke`); the facades call it through `Adapty._invokeMethod`.
- **Android side:** `android/src/main/kotlin/com/adapty/flutter/AdaptyFlutterPlugin.kt` — bridges to the native Android Adapty SDK (dependency via BOM in `android/build.gradle`). `FlutterFileSource.kt` next to it decides where a file named by a custom asset or by `setFallback` comes from: a name that starts with `/` is a file path, any other name is a Flutter asset key.
- **iOS side:** `ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyFlutterPlugin.swift` — bridges to the native iOS Adapty SDK (dependency via Swift Package Manager in `ios/adapty_flutter/Package.swift`). iOS is SPM-only as of 4.0.0 (no podspec).

All method names and argument keys are centralized in `lib/src/constants/method.dart` and `lib/src/constants/argument.dart`.

### Cross-Platform Protocol

`contract/cross_platform.yaml` is a JSON Schema defining the request/response contract between Dart and native code. When adding or changing a method, this schema should stay in sync. It is a byte-for-byte copy of the iOS `Sources.AdaptyPlugin/cross_platform.yaml`: sync the copy into `contract/` (never into the repository root) and update `contract/CONTRACT_SOURCE` (the schema hash and the iOS commit it was copied from) in the same commit; `test/contract/` fails until both agree.

### Models & Serialization

All data models live in `lib/src/models/`. Each model has a corresponding `*JSONBuilder` in `lib/src/models/private/` that handles JSON serialization/deserialization. The base helpers (`Map<String, dynamic>` extensions for typed access) are in `lib/src/models/private/json_builder.dart`.

Public exports are controlled via `lib/adapty_flutter.dart` using explicit `show` clauses.

### Event System

Native events are decoded and routed in `lib/src/runtime/event_dispatcher.dart` (`AdaptyEventDispatcher`), on the runtime the event arrived on; the incoming handler binds that runtime around the dispatch. Flow and onboarding events reach the observer interfaces (`AdaptyUIFlowsEventsObserver`, `AdaptyUIOnboardingsEventsObserver`, `lib/src/adaptyui_observer.dart`) through `lib/src/adaptyui_events_proxy.dart`. Profile updates, promoted purchases and installation details go to broadcast streams kept in `AdaptyRuntime.core`.

### Platform Views

Native paywall and onboarding views are embedded via `PlatformView` widgets in `lib/src/platform_views/`. Corresponding native view factories are in the Android/iOS directories.

## Key Patterns

- **Singletons:** `Adapty()` and `AdaptyUI()` are singleton facades over `AdaptyRuntime.current`.
- **SDK state:** new state the SDK keeps goes into a field of a holder in `AdaptyRuntime` (`lib/src/runtime/`), not into a field of `Adapty` or `AdaptyUI`.
- **Runtime access:** code that handles a native event takes its runtime as a parameter or through `runBound`. `AdaptyRuntime.current` is read only at the facade entry points, in the logger, in `AdaptySDKNative`, in the default handling of observers, in the model serialization that facades and widgets call (such as the once-only warning about ignored gradient settings in `adaptyui_custom_assets_gradient.dart`) and in the state of a platform view; inside the handling of an event it is the runtime of the event, through `runBound`.
- **Logging:** write with `AdaptyLogger.write`, or `writeAdaptyLogTo` with the log sink of a known runtime. The level filter is there, and `print` is only in `PrintLogSink` (`lib/src/runtime/adapty_log_sink.dart`). A test reads the log with `installTestRuntime(logSink: CapturingLogSink())`.
- **Test runtimes:** a unit test puts its own runtime in place with `installTestRuntime` (`test/support/test_runtime.dart`), over a `FakeTransport`. A contract test uses `installContractRuntime` (`test/support/contract/contract_runtime.dart`) instead: the runtime goes over the real adapty method channel, and `ContractNative` stands for the native side of one platform, checks every call against `contract/cross_platform.yaml` for that platform (with `contract/overlays/` and `contract/baseline/`) and answers from the corpus under `contract/`. Use it only in `test/contract/` and in its own self-test: disposing a runtime over the channel takes the incoming handler off the shared channel, which is safe only because every test file runs in an isolate of its own.
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
