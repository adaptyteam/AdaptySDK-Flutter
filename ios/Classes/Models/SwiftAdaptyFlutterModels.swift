//
//  SwiftAdaptyFlutterModels.swift
//  Adapty
//
//  Created by Тимофей Лемещенко on 8/13/20.
//

import Adapty
import Foundation

enum MethodName: String {
    case activate
    case identify
    case logout
    
    case getProfile = "get_profile"
    case getPaywall = "get_paywall"
    case getPaywallProducts = "get_paywall_products"
    
    case makePurchase = "make_purchase"
    case restorePurchases = "restore_purchases"
    case updateAttribution = "update_attribution"
    case makeDeferredPurchase = "make_deferred_purchase"

    case didUpdateProfile = "did_update_profile"
    case notImplemented = "not_implemented"

    case setLogLevel = "set_log_level"
    case updateProfile = "update_profile"
    case setFallbackPaywalls = "set_fallback_paywalls"
    case setApnsToken = "set_apns_token"
    case handlePushNotification = "handle_push_notification"
    case logShowPaywall = "log_show_paywall"
    case logShowOnboarding = "log_show_onboarding"
    case setTransactionVariationId = "set_transaction_variation_id"
    case presentCodeRedemptionSheet = "present_code_redemption_sheet"
}
