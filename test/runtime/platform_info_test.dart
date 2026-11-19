// ignore_for_file: deprecated_member_use_from_same_package

/// The platform comes from the runtime: the host platform in the app, the one a test spells out on a test runtime.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart' show AdaptyOnboardingJSONBuilder;
import 'package:adapty_flutter/src/models/adapty_sdk_native.dart';
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_platform_views.dart';
import '../support/test_platform_info.dart';
import '../support/test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AdaptySDKNative.debugPlatformOverride = null);

  test('HostPlatformInfo follows debugPlatformOverride for protocol branches', () {
    const host = HostPlatformInfo();

    AdaptySDKNative.debugPlatformOverride = TargetPlatform.android;
    expect((host.isIOS, host.isAndroid), (false, true));

    AdaptySDKNative.debugPlatformOverride = TargetPlatform.macOS;
    expect((host.isIOS, host.isAndroid), (true, false));
  });

  test('HostPlatformInfo builds platform views for the real host only', () {
    AdaptySDKNative.debugPlatformOverride = TargetPlatform.iOS;

    expect(const HostPlatformInfo().viewKind, AdaptyPlatformViewKind.none);
  });

  test('HostPlatformInfo maps the host operating system', () {
    AdaptySDKNative.debugPlatformOverride = null;

    (bool, bool, AdaptyPlatformViewKind, String) answersFor(String os) {
      final host = HostPlatformInfo.forOperatingSystem(os);
      return (host.isIOS, host.isAndroid, host.viewKind, host.logTag);
    }

    expect(
      {
        for (final os in ['ios', 'android', 'macos', 'linux']) os: answersFor(os),
      },
      {
        'ios': (true, false, AdaptyPlatformViewKind.uiKit, 'i'),
        'android': (false, true, AdaptyPlatformViewKind.android, 'a'),
        'macos': (true, false, AdaptyPlatformViewKind.none, 'i'),
        'linux': (false, false, AdaptyPlatformViewKind.none, 'i'),
      },
    );
  });

  test('AdaptySDKNative asks the current runtime', () {
    installTestRuntime(
      platform: const TestPlatformInfo(
        isIOS: false,
        isAndroid: true,
        viewKind: AdaptyPlatformViewKind.none,
        logTag: 'i',
      ),
    );

    expect((AdaptySDKNative.isIOS, AdaptySDKNative.isAndroid), (false, true));
  });

  testWidgets('a flow platform view builds a UiKitView when the runtime platform says uiKit', (tester) async {
    final views = FakePlatformViews.install(tester);
    installTestRuntime(platform: _platformWithViews(AdaptyPlatformViewKind.uiKit));

    await tester.pumpWidget(_hosted(AdaptyUIFlowPlatformView(flow: _flow())));

    expect(find.byType(UiKitView), findsOneWidget);
    expect(views.created.map((view) => view.viewType), ['adaptyui_flow_platform_view']);
  });

  testWidgets('a flow platform view builds an AndroidView when the runtime platform says android', (tester) async {
    final views = FakePlatformViews.install(tester);
    installTestRuntime(platform: _platformWithViews(AdaptyPlatformViewKind.android));

    await tester.pumpWidget(_hosted(AdaptyUIFlowPlatformView(flow: _flow())));

    expect(find.byType(AndroidView), findsOneWidget);
    expect(views.created.map((view) => view.viewType), ['adaptyui_flow_platform_view']);
  });

  testWidgets('an onboarding platform view builds a UiKitView when the runtime platform says uiKit', (tester) async {
    final views = FakePlatformViews.install(tester);
    installTestRuntime(platform: _platformWithViews(AdaptyPlatformViewKind.uiKit));

    await tester.pumpWidget(_hosted(AdaptyUIOnboardingPlatformView(onboarding: _onboarding())));

    expect(find.byType(UiKitView), findsOneWidget);
    expect(views.created.map((view) => view.viewType), ['adaptyui_onboarding_platform_view']);
  });

  testWidgets('an onboarding platform view builds an AndroidView when the runtime platform says android', (
    tester,
  ) async {
    final views = FakePlatformViews.install(tester);
    installTestRuntime(platform: _platformWithViews(AdaptyPlatformViewKind.android));

    await tester.pumpWidget(_hosted(AdaptyUIOnboardingPlatformView(onboarding: _onboarding())));

    expect(find.byType(AndroidView), findsOneWidget);
    expect(views.created.map((view) => view.viewType), ['adaptyui_onboarding_platform_view']);
  });

  test('the logger takes its prefix letter from the runtime platform', () {
    installTestRuntime(
      platform: const TestPlatformInfo(
        isIOS: false,
        isAndroid: false,
        viewKind: AdaptyPlatformViewKind.none,
        logTag: 'a',
      ),
    );
    final lines = <String>[];

    runZoned(
      () => AdaptyLogger.write(AdaptyLogLevel.warn, 'x'),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
    );

    expect(lines, [startsWith('[AdaptyFlutter a')]);
  });
}

/// A platform whose only difference from the test host is the kind of platform view.
TestPlatformInfo _platformWithViews(AdaptyPlatformViewKind viewKind) =>
    TestPlatformInfo(isIOS: false, isAndroid: false, viewKind: viewKind, logTag: 'i');

Widget _hosted(Widget view) => Directionality(textDirection: TextDirection.ltr, child: view);

AdaptyFlow _flow() => AdaptyFlowJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'flow_id': 'flow-id',
  'flow_name': 'Flow',
  'variation_id': 'variation-id',
  'remote_configs': <dynamic>[],
  'variations': <dynamic>[],
  'ui_schema': {
    'layouts': [
      {'flow_layout_id': 'flow-layout-id'},
    ],
    'grids': <dynamic>[],
  },
  'response_created_at': 0,
});

AdaptyOnboarding _onboarding() => AdaptyOnboardingJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'onboarding_id': 'onboarding-id',
  'onboarding_name': 'Onboarding',
  'variation_id': 'variation-id',
  'response_created_at': 0,
  'onboarding_builder': {'config_url': 'https://example.com/config'},
  'request_locale': 'en',
});
