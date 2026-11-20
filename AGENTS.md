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

# Run the contract tests only: the SDK against contract/, without a device
flutter test test/contract
# The contract request tests in a timezone ahead of UTC, as CI runs them once more
TZ=Asia/Dubai flutter test test/contract/requests_test.dart test/contract/platform_view_params_test.dart
# Rewrite the golden cases under contract/ after an intended change; a second run without the variable must pass
ADAPTY_CONTRACT_UPDATE=1 flutter test test/contract/requests_test.dart test/contract/event_responses_test.dart test/contract/platform_view_params_test.dart

# Format: the line width of the project is 120, and without -l 120 the formatter rewrites most files
dart format -l 120 <files>

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
# Its cases are generated from contract/ and git-ignored: generate them first, or the analyzer reports the missing file.
# --discover writes every case, also one without a recorded outcome; without it the bundle is strict, as on a device.
dart run tool/l2a/bundle_cases.dart --discover
cd integration_test_app && flutter pub get && flutter analyze
cd integration_test_app && flutter build apk --debug
# iOS: build for one named simulator; `flutter build ios --simulator` fails with Xcode 27 (it builds two architectures).
# Keep FLUTTER_TARGET: after any `flutter test` on iOS, ios/Flutter/Generated.xcconfig still points at a deleted
# temporary test entry point, and xcodebuild fails without the override.
cd integration_test_app/ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination 'platform=iOS Simulator,name=<simulator>' -derivedDataPath <dir> \
  FLUTTER_TARGET=lib/main.dart COMPILER_INDEX_STORE_ENABLE=NO build

# Run the native probe before activation, as CI does: the bundle of cases, the probe of the channel, the embedded views
# and the native logs, with a summary at the end (logs under build/l2a/<platform> unless a directory is given).
# `local` uses the simulator L2A-iPhone-it, the AVD L2A_API_36_it on emulator-5580 and the Flutter of .fvmrc under ~/fvm.
tool/l2a/ci/ios.sh local [<output directory>]
tool/l2a/ci/android.sh local [<output directory>] [--flutter-activity]  # with --flutter-activity: a plain FlutterActivity

# Run the JVM unit tests of the Android plugin (android/src/test) through the example app's Gradle project (needs JDK 17+)
cd example && flutter pub get && flutter build apk --config-only && cd android && ./gradlew :adapty_flutter:testDebugUnitTest
```

The Android unit tests passed only if `example/build/adapty_flutter/test-results/testDebugUnitTest/TEST-*.xml` exist and report `tests` greater than 0 with `failures="0"`. `BUILD SUCCESSFUL` alone proves nothing: when Gradle finds no test sources (for example, `pub get` was run in another checkout, so `.flutter-plugins-dependencies` points the example at another copy of the plugin), the task is `NO-SOURCE` and the build still succeeds.

CI is `.github/workflows/ci.yml` (Linux: analyze + test for the root package and for the example, the contract request tests once more with `TZ=Asia/Dubai`, the analysis of the integration test app after its cases are generated with `--discover`, the public API check against `tool/api/public_api.json`, and the JVM unit tests of the Android plugin). The runner is in UTC, where a local midnight is the same day in UTC; ahead of UTC it falls on the day before, so a date the SDK sends from a local time is checked there too (`test/tool/ci_timezone_step_test.dart` keeps the step; `test/tool/ci_app_analysis_step_test.dart` keeps the analysis of the integration test app). `.github/workflows/l2a.yml` runs the native probe on an iOS simulator (macOS, a fixed Xcode version) and an Android emulator (`google_apis`, so that `adb root` works for the egress guard) with `tool/l2a/ci/{ios,android}.sh ci`. Every pull request into `dev`, `master`, `release/**` and `hotfix/**` runs it, and a change filter skips the devices when nothing native changed; `l2a-gate` is the one check to require, green only when the filter succeeded and every job passed or was skipped. `tool/l2a/summary.dart` writes the job summary: a failure is `infra` (the run did not get to the plugin) or `probe` (the plugin answered other than expected), and an iOS SDK other than `probed.ios_sha` of `integration_test_app/l2a_expectations.yaml` is the warning `native-moved`, not a failure. The nightly schedule starts the workflow on `dev`, where it also runs the probe with a plain FlutterActivity. Nightly and manual runs (`workflow_dispatch`) work once the workflow is on the default branch, `master`: until a release brings it there, only pull requests run it. `test/tool/l2a_workflow_test.dart` keeps the decisions of the workflow and tests the gate and the egress guard without devices. The published package leaves out the tests of the contract and of the native probe and what only they read (`.pubignore`; the schema `contract/cross_platform.yaml` stays). pub reads `.pubignore` instead of `.gitignore`, so a rule added to `.gitignore` goes into both, and a rule of `.pubignore` starts with `/`: without it, `contract/` would also match `test/contract/` and `tool/contract/`. `test/tool/pubignore_test.dart` keeps both and checks that no test the package keeps imports a file it leaves out; `dart pub publish --dry-run` (after taking `publish_to: none` out of a copy of `pubspec.yaml`) shows the files and the size. There is no custom Makefile or lint script in this repo. The linting config is minimal — `analysis_options.yaml` sets max line length to 120.

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

The tests under `test/contract/` check every request the SDK sends, and every response and event it reads, against this schema for each platform, without a device (`ContractNative`, see Test runtimes below). What they read is under `contract/`: the fixtures — `requests/` (the golden requests the SDK has to send), `responses/` and `events/` (what each native writes) and `pseudo/` (the creation parameters of the embedded views) —, `overlays/` (what one platform requires, adds or leaves out of the schema), `baseline/known_discrepancies.yaml` (known differences between the SDK and the contract, each with the case that still shows it) and `coverage_exceptions.yaml` (schema properties no fixture of a platform can carry: the platform never writes them, no call the SDK makes reaches them, or they never come in a real payload). A fixture follows the native coder of its platform and names its files and lines in `notes`; it is never changed to make a test pass. A row of an overlay, of the baseline or of the coverage exceptions is added only after the difference has been checked against the native code, and it names that code in `source` (or the decision in `finding`). Schema, validator and corpus are plain Dart under `tool/contract/`, without Flutter imports; `yaml` is their only dev dependency.

To resync after a new schema copy or a moved native pin: update the fields of `contract/CONTRACT_SOURCE` (`schema_sha256`, `schema_version`, `counts`, `ios.ref` and `ios.synced_sha`, `android.bom` and `android.crossplatform`) in the same commit; rewrite the golden cases with `ADAPTY_CONTRACT_UPDATE=1` (the command above; the writer refuses a request that is not what the table in `test/contract/support/api_calls.dart` says) and check that a second run without it leaves `git status` clean; then `test/contract/corpus_test.dart` lists the fixtures the new schema rejects, the working list for checking them against the native coders. The `provenance` and `notes` of a fixture keep the native ref it was written against; the `source` of an overlay or baseline row has to name the ref of the record. The same holds for the other records under the ref: check each row of `contract/coverage_exceptions.yaml`, `contract/request_value_exceptions.yaml` and `contract/error_codes.yaml` (the codes each native declares and the lines that declare them) against the natives of the new ref and move its `source` to it; `test/contract/schema_coverage_test.dart`, `test/contract/request_values_test.dart` and `test/contract/error_codes_test.dart` list what no longer holds. The outcomes in `integration_test_app/l2a_expectations.yaml` are recorded on devices: record them again on the new natives (below) and update `probed` to the natives, the iOS runtime and the Xcode they were recorded on.

To record the probe expectations — after a new golden case, a moved native ref or a changed plugin: generate the bundle with `--discover`, which observes a case without a recorded outcome instead of stopping on it; run `cd integration_test_app && flutter test integration_test/l2a_discover_test.dart -d <device>` on the simulator and on the emulator, which prints one `L2A_OUTCOME` line per case (the expected outcome, what the plugin answered and whether they match) and an `L2A_SUMMARY` line; for each case whose answer differs from the defaults of `integration_test_app/l2a_expectations.yaml`, write a row with the outcome, a reason and a `source` in the native code of the ref (an answer is recorded only once it is explained by that code, never to make the run pass); then generate the strict bundle (without `--discover`), which stops on any case that still has no outcome, run `tool/l2a/ci/{ios,android}.sh local`, and update `probed`.

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
- `contract/CONTRACT_SOURCE` — the iOS ref and the Android BOM and bridge versions the contract was checked against; a bump of the BOM or of the iOS pin without it fails `test/contract/contract_source_test.dart`
- `tool/kids/Package.swift` — the same iOS pin for the generated `adapty_flutter_kids` variant; keep it identical to `ios/adapty_flutter/Package.swift` apart from the `KidsMode` trait
- `CHANGELOG.md`
- `pubspec.yaml` `publish_to: none` — present on development (`-dev.N`) versions; remove it at the release cut, together with the version bump.
