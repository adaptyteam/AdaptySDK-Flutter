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

//    let onCall: Listener
    let channel: FlutterMethodChannel
    
    init(channel: FlutterMethodChannel)
    {
        self.channel = channel
    }
    
    func invokeMethod(
        _ method: Method,
        arguments: [Argument: Result<Data, Error>]
    )
    {
//        channel?.invokeMethod(method, arguments: args)
        
        do
        {
            
            try channel.invokeMethod(
                method.rawValue,
                arguments: Dictionary( //  TODO: Dictionary.init(uniqueKeysAndValues:) crashes on duplicate keys.
                    uniqueKeysWithValues: arguments.map
                    { key, value in
                        try (key.rawValue, value.get())
                    }
                )
            )
            
//            try onCall(
//                method.rawValue,
//                Dictionary( //  TODO: Dictionary.init(uniqueKeysAndValues:) crashes on duplicate keys.
//                    uniqueKeysWithValues: arguments.map
//                    { key, value in
//                        try (key.rawValue, value.asAdaptyJsonData.asAdaptyJsonString)
//                    }
//                )
//            )
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
                .view: Result { try controller.asAdaptyJsonData },
                .action: Result { try action.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .product: Result { try product.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .product: Result { try product.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .product: Result { try product.asAdaptyJsonData },
                .purchasedResult: Result { try purchaseResult.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .product: Result { try product.asAdaptyJsonData },
                .error: Result { try error.asAdaptyJsonData },
            ]
        )
    }
        
    public func paywallControllerDidStartRestore(_ controller: AdaptyPaywallController)
    {
        invokeMethod(
            .paywallViewDidStartRestore,
            arguments: [
                .view: Result { try controller.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .profile: Result { try profile.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .error: Result { try error.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .error: Result { try error.asAdaptyJsonData },
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
                .view: Result { try controller.asAdaptyJsonData },
                .error: Result { try error.asAdaptyJsonData },
            ]
        )
            
        return true
    }
}
