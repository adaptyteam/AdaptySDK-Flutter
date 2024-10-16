class Method {
  static const String activate = 'activate';
  static const String setLogLevel = 'set_log_level';
  static const String getProfile = 'get_profile';
  static const String updateProfile = 'update_profile';
  static const String identify = 'identify';
  static const String getPaywall = 'get_paywall';
  static const String getPaywallProducts = 'get_paywall_products';
  static const String getProductsIntroductoryOfferEligibility = 'get_products_introductory_offer_eligibility';
  static const String makePurchase = 'make_purchase';
  static const String restorePurchases = 'restore_purchases';
  static const String updateAttribution = 'update_attribution';
  static const String logShowPaywall = 'log_show_paywall';
  static const String logShowOnboarding = 'log_show_onboarding';
  static const String setTransactionVariationId = 'set_transaction_variation_id';
  static const String setFallbackPaywalls = 'set_fallback_paywalls';
  static const String logout = 'logout';
  static const String presentCodeRedemptionSheet = 'present_code_redemption_sheet';
}

class IncomingMethod {
  static const String didUpdateProfile = 'did_update_profile';
}
