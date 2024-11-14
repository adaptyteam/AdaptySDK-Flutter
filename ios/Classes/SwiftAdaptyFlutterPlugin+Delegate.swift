//
//  File.swift
//  Adapty
//
//  Created by Aleksey Goncharov on 13.11.2024.
//

import Adapty
import AdaptyPlugin
import AdaptyUI
import Flutter
import Foundation

private let log = Log.wrapper

final class SwiftAdaptyFlutterPluginDelegate: NSObject
{
    public typealias Listener = (String, [String: String]) -> Void

    let onCall: Listener
    
    init(onCall: @escaping Listener)
    {
        self.onCall = onCall
    }
    
    func invokeMethod(
        _ method: Method,
        arguments: [Argument: AdaptyJsonDataRepresentable]
    )
    {
        do
        {
            try onCall(
                method.rawValue,
                Dictionary( //  TODO: Dictionary.init(uniqueKeysAndValues:) crashes on duplicate keys. 
                    uniqueKeysWithValues: arguments.map
                    { key, value in
                        try (key.rawValue, value.asAdaptyJsonData.asAdaptyJsonString)
                    }
                )
            )
        }
        catch
        {
            log.error("Plugin encoding error: \(error.localizedDescription)")
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
extension SwiftAdaptyFlutterPluginDelegate: AdaptyPaywallControllerDelegate
{
    public func paywallController(_ controller: AdaptyPaywallController, didPerform action: AdaptyUI.Action)
    {
        invokeMethod(
            .paywallViewDidPerformAction,
            arguments: [
                .view: controller.wrap,
                .action: action,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didSelectProduct product: AdaptyPaywallProductWithoutDeterminingOffer
    )
    {
        invokeMethod(
            .paywallViewDidSelectProduct,
            arguments: [
                .view: controller.wrap,
//                .product: product.wrap, // TODO:
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didStartPurchase product: AdaptyPaywallProduct
    )
    {
        invokeMethod(
            .paywallViewDidStartPurchase,
            arguments: [
                .view: controller.wrap,
                .product: product.wrap,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didCancelPurchase product: AdaptyPaywallProduct
    )
    {
        invokeMethod(
            .paywallViewDidCancelPurchase,
            arguments: [
                .view: controller.wrap,
                .product: product.wrap,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFinishPurchase product: AdaptyPaywallProduct,
        purchaseResult: AdaptyPurchaseResult
    )
    {
        invokeMethod(
            .paywallViewDidFinishPurchase,
            arguments: [
                .view: controller.wrap,
                .product: product.wrap,
                .purchasedResult: purchaseResult,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFailPurchase product: AdaptyPaywallProduct,
        error: AdaptyError
    )
    {
        invokeMethod(
            .paywallViewDidFailPurchase,
            arguments: [
                .view: controller.wrap,
                .product: product.wrap,
                .error: error,
            ]
        )
    }
        
    public func paywallControllerDidStartRestore(_ controller: AdaptyPaywallController)
    {
        invokeMethod(
            .paywallViewDidStartRestore,
            arguments: [
                .view: controller.wrap,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFinishRestoreWith profile: AdaptyProfile
    )
    {
        invokeMethod(
            .paywallViewDidFinishRestore,
            arguments: [
                .view: controller.wrap,
                .profile: profile,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFailRestoreWith error: AdaptyError
    )
    {
        invokeMethod(
            .paywallViewDidFailRestore,
            arguments: [
                .view: controller.wrap,
                .error: error,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFailRenderingWith error: AdaptyError
    )
    {
        invokeMethod(
            .paywallViewDidFailRendering,
            arguments: [
                .view: controller.wrap,
                .error: error,
            ]
        )
    }
        
    public func paywallController(
        _ controller: AdaptyPaywallController,
        didFailLoadingProductsWith error: AdaptyError
    ) -> Bool
    {
        invokeMethod(
            .paywallViewDidFailLoadingProducts,
            arguments: [
                .view: controller.wrap,
                .error: error,
            ]
        )
            
        return true
    }
}

struct AdaptyPaywallWrapper: AdaptyJsonDataRepresentable
{
    let wrapped: AdaptyPaywallProduct
    
    init(wrapped: AdaptyPaywallProduct)
    {
        self.wrapped = wrapped
    }
    
    @inlinable
    public var asAdaptyJsonData: Data
    {
        get throws
        {
            try wrapped.asAdaptyJsonData
        }
    }
}

extension AdaptyPaywallProduct
{
    var wrap: AdaptyPaywallWrapper
    {
        .init(wrapped: self)
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
struct AdaptyPaywallControllerWrapper: AdaptyJsonDataRepresentable
{
    let wrapped: AdaptyPaywallController
    
    init(wrapped: AdaptyPaywallController)
    {
        self.wrapped = wrapped
    }
    
    @inlinable
    public var asAdaptyJsonData: Data
    {
        get throws
        {
            try wrapped.asAdaptyJsonData
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
extension AdaptyPaywallController
{
    var wrap: AdaptyPaywallControllerWrapper
    {
        .init(wrapped: self)
    }
}
