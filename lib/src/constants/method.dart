class Method {
  static const String activate = 'activate';
  static const String setLogLevel = 'set_log_level';
  static const String getProfile = 'get_profile';
  static const String updateProfile = 'update_profile';
  static const String identify = 'identify';
  static const String getPaywall = 'get_paywall';
  static const String getPaywallForDefaultAudience = 'get_paywall_for_default_audience';
  static const String getPaywallProducts = 'get_paywall_products';
  static const String makePurchase = 'make_purchase';
  static const String restorePurchases = 'restore_purchases';
  static const String updateAttribution = 'update_attribution_data';
  static const String logShowPaywall = 'log_show_paywall';
  static const String logShowOnboarding = 'log_show_onboarding';
  static const String setFallbackPaywalls = 'set_fallback_paywalls';
  static const String logout = 'logout';
  static const String presentCodeRedemptionSheet = 'present_code_redemption_sheet';
  static const String getSDKVersion = 'get_sdk_version';
  static const String isActivated = 'is_activated';
  static const String reportTransaction = 'report_transaction';

  static const String setIntegrationIdentifiers = 'set_integration_identifiers';
  static const String updateCollectingRefundDataConsent = 'update_collecting_refund_data_consent';
  static const String updateRefundPreference = 'update_refund_preference';

  static const String createWebPaywallUrl = 'create_web_paywall_url';
  static const String openWebPaywall = 'open_web_paywall';

  static const String activateUI = 'adapty_ui_activate';
  static const String createView = 'adapty_ui_create_view';
  static const String presentView = 'adapty_ui_present_view';
  static const String dismissView = 'adapty_ui_dismiss_view';
  static const String showDialog = 'adapty_ui_show_dialog';
}

class IncomingMethod {
  static const String paywallViewDidAppear = 'paywall_view_did_appear';
  static const String paywallViewDidDisappear = 'paywall_view_did_disappear';
  static const String paywallViewDidPerformAction = 'paywall_view_did_perform_action';
  static const String paywallViewDidPerformSystemBackAction = 'paywall_view_did_perform_system_back_action';
  static const String paywallViewDidSelectProduct = 'paywall_view_did_select_product';
  static const String paywallViewDidStartPurchase = 'paywall_view_did_start_purchase';
  static const String paywallViewDidFinishPurchase = 'paywall_view_did_finish_purchase';
  static const String paywallViewDidFailPurchase = 'paywall_view_did_fail_purchase';
  static const String paywallViewDidStartRestore = 'paywall_view_did_start_restore';
  static const String paywallViewDidFinishRestore = 'paywall_view_did_finish_restore';
  static const String paywallViewDidFailRestore = 'paywall_view_did_fail_restore';
  static const String paywallViewDidFailRendering = 'paywall_view_did_fail_rendering';
  static const String paywallViewDidFailLoadingProducts = 'paywall_view_did_fail_loading_products';
  static const String paywallViewDidFinishWebPaymentNavigation = 'paywall_view_did_finish_web_payment_navigation';

  static const String didLoadLatestProfile = 'did_load_latest_profile';
}
