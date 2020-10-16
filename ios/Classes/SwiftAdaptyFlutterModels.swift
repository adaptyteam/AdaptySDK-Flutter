//
//  SwiftAdaptyFlutterModels.swift
//  Adapty
//
//  Created by Тимофей Лемещенко on 8/13/20.
//

import Foundation

enum MethodName: String {
    case activate = "activate"
    case identify = "identify"
    case getPaywalls = "get_paywalls"
    case getPaywallsResult = "get_paywalls_result"
    case makePurchase = "make_purchase"
    case validateReceipt = "validate_receipt"
    case restorePurchases = "restore_purchases"
    case getPurchaserInfo = "get_purchaser_info"
    case getActivePurchases = "get_active_purchases"
    case getActivePurchasesResult = "get_active_purchases_result"
    case updateAttribution = "update_attribution"
    case makeDeferredPurchase = "make_deferred_purchase"
    case defferedPurchaseProduct = "deferred_purchase_product"
    case purchaserInfoUpdate = "purchaser_info_update"
    case logout = "logout"
    case notImplemented = "not_implemented"
}

enum SourceType: String {
    case adjust = "adjust"
    case appsflyer = "appsflyer"
    case branch = "branch"
}

struct GetPaywallsResult: Codable {
    let paywalls: [String]
    let products: [AdaptyProduct]
}

struct AdaptyProduct: Codable {
    let id: String
    let title: String
    let description: String
    let price: String
    let localizedPrice: String
    let currency: String
}

struct MakePurchaseResult: Codable {
    let receipt: String?
}

struct GetActivePurchasesResult: Codable {
    let activeSubscription: Bool
    let activeSubscriptionProductId: String?
    let nonSubscriptionsProductIds: [String]
}

struct UpdatedPurchaserInfo: Codable {
    let nonSubscriptionsProductIds: [String]
    let activePaidAccessLevels: [String]
    let activeSubscriptionsIds: [String]
}
