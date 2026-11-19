/// The names the SDK uses on the channel to the native side. The expected maps are written out by
/// hand: compared as maps rather than sets, they also catch two values that swapped their names.
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/native_wire_names.dart';

const _methodWireNames = <String, String>{
  'activate': 'activate',
  'setLogLevel': 'set_log_level',
  'getProfile': 'get_profile',
  'updateProfile': 'update_profile',
  'identify': 'identify',
  'getFlow': 'get_flow',
  'getFlowForDefaultAudience': 'get_flow_for_default_audience',
  'preloadFlows': 'preload_flows',
  'preloadFlowsForDefaultAudience': 'preload_flows_for_default_audience',
  'getPaywallProducts': 'get_paywall_products',
  'getOnboarding': 'get_onboarding',
  'getOnboardingForDefaultAudience': 'get_onboarding_for_default_audience',
  'makePurchase': 'make_purchase',
  'makePromotedPurchase': 'make_promoted_purchase',
  'restorePurchases': 'restore_purchases',
  'updateExternalAttribution': 'update_external_attribution_data',
  'logShowFlow': 'log_show_flow',
  'setFallback': 'set_fallback',
  'logout': 'logout',
  'presentCodeRedemptionSheet': 'present_code_redemption_sheet',
  'isActivated': 'is_activated',
  'reportTransaction': 'report_transaction',
  'setIntegrationIdentifiers': 'set_integration_identifiers',
  'updateCollectingRefundDataConsent': 'update_collecting_refund_data_consent',
  'updateRefundPreference': 'update_refund_preference',
  'createWebPaywallUrl': 'create_web_paywall_url',
  'openWebPaywall': 'open_web_paywall',
  'getPendingStoreMessageTypes': 'get_pending_store_message_types',
  'showStoreMessages': 'show_store_messages',
  'getCurrentInstallationStatus': 'get_current_installation_status',
  'createFlowView': 'adapty_ui_create_flow_view',
  'presentFlowView': 'adapty_ui_present_flow_view',
  'dismissFlowView': 'adapty_ui_dismiss_flow_view',
  'destroyFlowView': 'adapty_ui_destroy_flow_view',
  'sendAppMessage': 'adapty_ui_send_app_message',
  'createOnboardingView': 'adapty_ui_create_onboarding_view',
  'presentOnboardingView': 'adapty_ui_present_onboarding_view',
  'dismissOnboardingView': 'adapty_ui_dismiss_onboarding_view',
  'showDialog': 'adapty_ui_show_dialog',
  'openUrl': 'adapty_ui_open_url',
  'requestAppReview': 'adapty_ui_request_app_review',
};

const _eventResponseWireNames = <String, String>{
  'flowViewDidAnswerPermission': 'flow_view_did_answer_permission',
  'observerPurchaseDidStart': 'observer_purchase_did_start',
  'observerPurchaseDidFinish': 'observer_purchase_did_finish',
  'observerRestoreDidStart': 'observer_restore_did_start',
  'observerRestoreDidFinish': 'observer_restore_did_finish',
};

void main() {
  test('the enums carry exactly the wire names the old constants had', () {
    expect({for (final e in NativeMethod.values) e.name: e.wireName}, _methodWireNames);
    expect({for (final e in NativeEventResponse.values) e.name: e.wireName}, _eventResponseWireNames);
    expect({for (final e in NativeEvent.values) e.name: e.wireName}, nativeEventWireNames);
  });

  test('event wire names round-trip and an unknown name is null', () {
    for (final e in NativeEvent.values) {
      expect(NativeEvent.fromWireName(e.wireName), e, reason: e.wireName);
    }
    expect(NativeEvent.fromWireName('not_an_event'), isNull);
  });
}
