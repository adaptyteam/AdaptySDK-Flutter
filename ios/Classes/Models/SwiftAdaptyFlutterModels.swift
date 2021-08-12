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
    case getPaywalls = "get_paywalls"
    case getPaywallsResult = "get_paywalls_result"
    case makePurchase = "make_purchase"
    case restorePurchases = "restore_purchases"
    case getPurchaserInfo = "get_purchaser_info"
    case getActivePurchasesResult = "get_active_purchases_result"
    case updateAttribution = "update_attribution"
    case makeDeferredPurchase = "make_deferred_purchase"
    case defferedPurchaseProduct = "deferred_purchase_product"
    case purchaserInfoUpdate = "purchaser_info_update"
    case getPromo = "get_promo"
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
    
    case showVisualPaywall = "show_visual_paywall"
    case closeVisualPaywall = "close_visual_paywall"
    
    case visualPaywallPurchaseSuccessResult = "visual_paywall_purchase_success_result"
    case visualPaywallPurchaseFailResult = "visual_paywall_purchase_failure_result"
    case visualPaywallCancelResult = "visual_paywall_cancel_result"
    case visualPaywallRestoreResult = "visual_paywall_restore_purchases_result"
}

struct GetPaywallsResult: Codable {
    let paywalls: [PaywallModel]?
    let products: [ProductModel]?
}

struct MakePurchaseResult: Codable {
    let purchaserInfo: PurchaserInfoModel?
    let receipt: String?
//    let appleValidationResult: [String: Any]?
    let product: ProductModel?
}

struct RestorePurchasesResult: Codable {
    let purchaserInfo: PurchaserInfoModel?
    let receipt: String?
//    let appleValidationResult: [String: Any]?
    let errorString: String?
}

struct VisualPaywallPurchaseFailResult: Codable {
    let product: ProductModel
    let errorString: String
}

extension AdaptyLogLevel: Codable {}

extension AdaptyError: Encodable {
    enum CodingKeys: String, CodingKey {
        case code
        case message
        case domain
        case adaptyCode
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(code, forKey: .code)
        try container.encode(localizedDescription, forKey: .message)
        try container.encode(domain, forKey: .domain)
        try container.encode(adaptyErrorCode.rawValue, forKey: .adaptyCode)
    }
}

extension AttributionNetwork {
    static func fromString(_ value: String) -> AttributionNetwork {
        switch value {
        case "adjust":
            return .adjust
        case "appsflyer":
            return .appsflyer
        case "branch":
            return .branch
        case "appleSearchAds":
            return .appleSearchAds
        default:
            return .custom
        }
    }
}
