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
//    case getPaywalls = "get_paywalls"
    case getPaywallsResult = "get_paywalls_result"
    case makePurchase = "make_purchase"
    case restorePurchases = "restore_purchases"
    case getPurchaserInfo = "get_purchaser_info"
    case getActivePurchasesResult = "get_active_purchases_result"
    case updateAttribution = "update_attribution"
    case makeDeferredPurchase = "make_deferred_purchase"
    case deferredPurchaseProduct = "deferred_purchase_product"
    case purchaserInfoUpdate = "purchaser_info_update"
    case promoReceived = "promo_received"
    case logout
    case notImplemented = "not_implemented"

    case getLogLevel = "get_log_level"
    case setLogLevel = "set_log_level"
    case updateProfile = "update_profile"
    case setFallbackPaywalls = "set_fallback_paywalls"
    case setApnsToken = "set_apns_token"
    case handlePushNotification = "handle_push_notification"
    case logShowPaywall = "log_show_paywall"
    case setExternalAnalyticsEnabled = "set_external_analytics_enabled"
    case setTransactionVariationId = "set_transaction_variation_id"
    case presentCodeRedemptionSheet = "present_code_redemption_sheet"
}
