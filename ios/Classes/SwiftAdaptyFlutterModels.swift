//
//  SwiftAdaptyFlutterModels.swift
//  Adapty
//
//  Created by Тимофей Лемещенко on 8/13/20.
//

import Foundation

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
