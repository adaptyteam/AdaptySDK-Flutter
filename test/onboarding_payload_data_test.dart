/// What an onboarding puts on the wire when it goes back to the native side: neither native side reads payload data
/// for an onboarding nor returns any, so an onboarding without it is sent without the key, not with a null.
// The onboarding API is deprecated; using it is exactly what these tests do.
// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart' show AdaptyOnboardingJSONBuilder;
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform_views.dart';
import 'support/test_platform_info.dart';
import 'support/test_runtime.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

const _uiKit = TestPlatformInfo(isIOS: false, isAndroid: false, viewKind: AdaptyPlatformViewKind.uiKit, logTag: 'i');
const _android = TestPlatformInfo(
  isIOS: false,
  isAndroid: false,
  viewKind: AdaptyPlatformViewKind.android,
  logTag: 'a',
);

Map<String, dynamic> _onboardingJson({String? payloadData}) => {
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
  if (payloadData != null) 'payload_data': payloadData,
};

AdaptyOnboarding _onboarding({String? payloadData}) =>
    AdaptyOnboardingJSONBuilder.fromJsonValue(_onboardingJson(payloadData: payloadData));

/// The onboarding inside the arguments of a call or the creation params of a platform view.
Map<String, dynamic> _sentOnboarding(Object? encodedArguments) =>
    (jsonDecode(encodedArguments! as String) as Map<String, dynamic>)['onboarding'] as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createOnboardingView', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        calls.add(call);
        return jsonEncode({
          'success': {'id': 'onboarding-view-1', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
        });
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    });

    test('sends an onboarding without payload data without the key', () async {
      await AdaptyUI().createOnboardingView(onboarding: _onboarding());

      expect(calls.single.method, 'adapty_ui_create_onboarding_view');
      expect(_sentOnboarding(calls.single.arguments), isNot(contains('payload_data')));
    });

    test('sends the payload data an onboarding carries', () async {
      await AdaptyUI().createOnboardingView(onboarding: _onboarding(payloadData: 'opaque-payload'));

      expect(calls.single.method, 'adapty_ui_create_onboarding_view');
      expect(_sentOnboarding(calls.single.arguments)['payload_data'], 'opaque-payload');
    });
  });

  testWidgets('an embedded onboarding view on iOS is created without payload data', (tester) async {
    installTestRuntime(platform: _uiKit);
    FakePlatformViews.install(tester);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AdaptyUIOnboardingPlatformView(onboarding: _onboarding()),
      ),
    );

    final view = tester.widget<UiKitView>(find.byType(UiKitView));
    expect(_sentOnboarding(view.creationParams), isNot(contains('payload_data')));
  });

  testWidgets('an embedded onboarding view on Android is created without payload data', (tester) async {
    installTestRuntime(platform: _android);
    FakePlatformViews.install(tester);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AdaptyUIOnboardingPlatformView(onboarding: _onboarding()),
      ),
    );

    final view = tester.widget<AndroidView>(find.byType(AndroidView));
    expect(_sentOnboarding(view.creationParams), isNot(contains('payload_data')));
  });
}
