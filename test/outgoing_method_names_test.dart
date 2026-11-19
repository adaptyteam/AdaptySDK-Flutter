// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart' show AdaptyOnboardingJSONBuilder;
import 'package:adapty_flutter/src/models/adapty_sdk_native.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_flow_view.dart' show AdaptyUIFlowViewJSONBuilder;
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_onboarding_view.dart'
    show AdaptyUIOnboardingViewJSONBuilder;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

final _flowView = AdaptyUIFlowViewJSONBuilder.fromJsonValue({
  'id': 'view-1',
  'placement_id': 'placement-id',
  'variation_id': 'variation-id',
});

final _onboardingView = AdaptyUIOnboardingViewJSONBuilder.fromJsonValue({
  'id': 'onboarding-view-1',
  'placement_id': 'placement-id',
  'variation_id': 'variation-id',
});

final _onboarding = AdaptyOnboardingJSONBuilder.fromJsonValue({
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

/// The method each call of the public API sends to the native side. Only the name is checked:
/// the native side answers every call with `{"success": null}`, so a call that expects a result
/// fails to parse it, and that failure is not what this table is about.
final _methods = <String, Future<Object?> Function()>{
  'logout': () => Adapty().logout(),
  'identify': () => Adapty().identify('user-1'),
  'restore_purchases': () => Adapty().restorePurchases(),
  'update_profile': () => Adapty().updateProfile(AdaptyProfileParametersBuilder().build()),
  'is_activated': () => Adapty().isActivated(),
  'get_current_installation_status': () => Adapty().getCurrentInstallationStatus(),
  'get_flow_for_default_audience': () => Adapty().getFlowForDefaultAudience(placementId: 'placement-id'),
  'get_onboarding': () => Adapty().getOnboarding(placementId: 'placement-id'),
  'get_onboarding_for_default_audience': () => Adapty().getOnboardingForDefaultAudience(placementId: 'placement-id'),
  'set_fallback': () => Adapty().setFallback('assets/fallback.json'),
  'set_integration_identifiers': () => Adapty().setIntegrationIdentifier(key: 'key', value: 'value'),
  'present_code_redemption_sheet': () => Adapty().presentCodeRedemptionSheet(),
  'update_collecting_refund_data_consent': () => Adapty().updateCollectingRefundDataConsent(true),
  'update_refund_preference': () => Adapty().updateRefundPreference(AdaptyRefundPreference.grant),
  'adapty_ui_present_flow_view': () => AdaptyUI().presentFlowView(_flowView),
  'adapty_ui_create_onboarding_view': () => AdaptyUI().createOnboardingView(onboarding: _onboarding),
  'adapty_ui_present_onboarding_view': () => AdaptyUI().presentOnboardingView(_onboardingView),
  'adapty_ui_dismiss_onboarding_view': () => AdaptyUI().dismissOnboardingView(_onboardingView),
  'adapty_ui_show_dialog': () =>
      AdaptyUI().showDialog('view-1', title: 'Title', content: 'Content', primaryActionTitle: 'OK'),
  'adapty_ui_open_url': () => AdaptyUI().openUrl('https://adapty.io'),
  'adapty_ui_request_app_review': () => AdaptyUI().requestAppReview(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    // The iOS-only calls return without reaching the native side on other platforms.
    AdaptySDKNative.debugPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return jsonEncode({'success': null});
    });
  });

  tearDown(() {
    AdaptySDKNative.debugPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  for (final MapEntry(key: method, value: call) in _methods.entries) {
    test('sends $method', () async {
      await call().then<void>((_) {}, onError: (Object _) {});

      expect(calls.map((call) => call.method), [method]);
    });
  }
}
