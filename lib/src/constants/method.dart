/// A call the SDK makes to the native side, by the name it has on the channel.
abstract interface class NativeRequest {
  String get wireName;

  /// The arguments of the call the log must not show, each as the path of its key from the top of the arguments, the
  /// keys joined with dots (`configuration.api_key`). The native side gets them as they are.
  List<String> get hiddenArguments;
}

enum NativeMethod implements NativeRequest {
  activate('activate'),
  setLogLevel('set_log_level'),
  getProfile('get_profile'),
  updateProfile('update_profile'),
  identify('identify'),

  getFlow('get_flow'),
  getFlowForDefaultAudience('get_flow_for_default_audience'),
  preloadFlows('preload_flows'),
  preloadFlowsForDefaultAudience('preload_flows_for_default_audience'),
  getPaywallProducts('get_paywall_products'),

  getOnboarding('get_onboarding'),
  getOnboardingForDefaultAudience('get_onboarding_for_default_audience'),

  makePurchase('make_purchase'),
  makePromotedPurchase('make_promoted_purchase'),
  restorePurchases('restore_purchases'),
  updateExternalAttribution('update_external_attribution_data'),
  logShowFlow('log_show_flow'),
  setFallback('set_fallback'),

  logout('logout'),
  presentCodeRedemptionSheet('present_code_redemption_sheet'),
  isActivated('is_activated'),
  reportTransaction('report_transaction'),

  setIntegrationIdentifiers('set_integration_identifiers'),
  updateCollectingRefundDataConsent('update_collecting_refund_data_consent'),
  updateRefundPreference('update_refund_preference'),

  createWebPaywallUrl('create_web_paywall_url'),
  openWebPaywall('open_web_paywall'),

  getPendingStoreMessageTypes('get_pending_store_message_types'),
  showStoreMessages('show_store_messages'),

  getCurrentInstallationStatus('get_current_installation_status'),

  createFlowView('adapty_ui_create_flow_view'),
  presentFlowView('adapty_ui_present_flow_view'),
  dismissFlowView('adapty_ui_dismiss_flow_view'),
  destroyFlowView('adapty_ui_destroy_flow_view'),
  sendAppMessage('adapty_ui_send_app_message'),

  createOnboardingView('adapty_ui_create_onboarding_view'),
  presentOnboardingView('adapty_ui_present_onboarding_view'),
  dismissOnboardingView('adapty_ui_dismiss_onboarding_view'),

  showDialog('adapty_ui_show_dialog'),
  openUrl('adapty_ui_open_url'),
  requestAppReview('adapty_ui_request_app_review');

  const NativeMethod(this.wireName);

  @override
  final String wireName;

  @override
  List<String> get hiddenArguments => switch (this) {
    activate => const ['configuration.api_key'],
    _ => const [],
  };
}

enum NativeEvent {
  flowViewDidAppear('flow_view_did_appear'),
  flowViewDidDisappear('flow_view_did_disappear'),
  flowViewDidPerformAction('flow_view_did_perform_action'),
  flowViewDidSelectProduct('flow_view_did_select_product'),
  flowViewDidStartPurchase('flow_view_did_start_purchase'),
  flowViewDidFinishPurchase('flow_view_did_finish_purchase'),
  flowViewDidFailPurchase('flow_view_did_fail_purchase'),
  flowViewDidStartRestore('flow_view_did_start_restore'),
  flowViewDidFinishRestore('flow_view_did_finish_restore'),
  flowViewDidFailRestore('flow_view_did_fail_restore'),
  flowViewDidReceiveError('flow_view_did_receive_error'),
  flowViewDidFailLoadingProducts('flow_view_did_fail_loading_products'),
  flowViewDidFinishWebPaymentNavigation('flow_view_did_finish_web_payment_navigation'),

  flowViewDidAskPermission('flow_view_did_ask_permission'), // flow_view_did_answer_permission + requestId
  flowViewDidRequestAppReview('flow_view_did_request_app_review'),
  flowViewDidReceiveAnalyticEvent('flow_view_did_receive_analytic_event'),
  flowViewObserverDidInitiatePurchase('flow_view_observer_did_initiate_purchase'),
  flowViewObserverDidInitiateRestore('flow_view_observer_did_initiate_restore'),

  onboardingDidFinishLoading('onboarding_did_finish_loading'),
  onboardingDidFailWithError('onboarding_did_fail_with_error'),
  onboardingOnAnalyticsActionEvent('onboarding_on_analytics_action'),
  onboardingOnCloseActionEvent('onboarding_on_close_action'),
  onboardingOnCustomActionEvent('onboarding_on_custom_action'),
  onboardingOnPaywallActionEvent('onboarding_on_paywall_action'),
  onboardingOnStateUpdatedActionEvent('onboarding_on_state_updated_action'),

  didLoadLatestProfile('did_load_latest_profile'),
  didReceivePromotedPurchase('did_receive_promoted_purchase'),
  onInstallationDetailsSuccess('on_installation_details_success'),
  onInstallationDetailsFail('on_installation_details_fail');

  const NativeEvent(this.wireName);

  final String wireName;

  static final _byWireName = {for (final event in values) event.wireName: event};

  /// The event with [wireName], or null for a name the SDK does not know.
  static NativeEvent? fromWireName(String wireName) => _byWireName[wireName];
}

enum NativeEventResponse implements NativeRequest {
  flowViewDidAnswerPermission('flow_view_did_answer_permission'),

  observerPurchaseDidStart('observer_purchase_did_start'),
  observerPurchaseDidFinish('observer_purchase_did_finish'),
  observerRestoreDidStart('observer_restore_did_start'),
  observerRestoreDidFinish('observer_restore_did_finish');

  const NativeEventResponse(this.wireName);

  @override
  final String wireName;

  @override
  List<String> get hiddenArguments => const [];
}
