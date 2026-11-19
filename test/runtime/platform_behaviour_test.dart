// ignore_for_file: deprecated_member_use_from_same_package

// How the SDK picks the platform today. The protocol branches follow `AdaptySDKNative.debugPlatformOverride`, so a
// test can run the iOS or Android path on any host; the letter in the log prefix and the kind of platform view
// follow the real host only.
//
// The tests set the override themselves, so they fail if the log letter or the kind of view starts to read it. The
// Android-only and iOS-only arguments under the override are covered by `report_transaction_jws_test.dart` and
// `store_messages_test.dart`.
import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart' show AdaptyOnboardingJSONBuilder;
import 'package:adapty_flutter/src/models/adapty_sdk_native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AdaptySDKNative.debugPlatformOverride = null);

  test('the log prefix letter is i on a non-Android host even with the android override', () {
    AdaptySDKNative.debugPlatformOverride = TargetPlatform.android;
    final lines = <String>[];

    runZoned(
      () => AdaptyLogger.write(AdaptyLogLevel.warn, 'x'),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
    );

    expect(AdaptySDKNative.isAndroid, isTrue, reason: 'the protocol branches do follow the override');
    expect(lines, [startsWith('[AdaptyFlutter i')]);
  });

  testWidgets(
    'an embedded flow view renders an empty box on a host that is neither iOS nor Android even with the iOS override',
    (tester) async {
      AdaptySDKNative.debugPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(_hosted(AdaptyUIFlowPlatformView(flow: _flow())));

      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(AndroidView), findsNothing);
      expect(
        find.descendant(of: find.byType(AdaptyUIFlowPlatformView), matching: find.byType(SizedBox)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an embedded onboarding view renders an empty box on a host that is neither iOS nor Android even with the iOS override',
    (tester) async {
      AdaptySDKNative.debugPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(_hosted(AdaptyUIOnboardingPlatformView(onboarding: _onboarding())));

      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(AndroidView), findsNothing);
      expect(
        find.descendant(of: find.byType(AdaptyUIOnboardingPlatformView), matching: find.byType(SizedBox)),
        findsOneWidget,
      );
    },
  );
}

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
