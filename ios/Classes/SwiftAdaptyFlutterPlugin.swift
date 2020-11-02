import Flutter
import Adapty

public class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
   
    private static var channel: FlutterMethodChannel? = nil
    
    private var paywalls = [PaywallModel?]()
    private var products = [String: ProductModel]()
    
    private var deferredPurchaseCompletion: DeferredPurchaseCompletion? = nil
    private var deferredPurchaseProductId: String? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: SwiftAdaptyFlutterConstants.channelName, binaryMessenger: registrar.messenger())
        let instance = SwiftAdaptyFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        self.channel = channel
    }

    public static func handlePushNotification(_ userInfo: [AnyHashable : Any], completion: @escaping ErrorCompletion) {
        Adapty.handlePushNotification(userInfo, completion: completion)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        switch MethodName.init(rawValue: call.method) ?? MethodName.notImplemented {
        case MethodName.activate:
            handleActivate(call, result: result, args: args)
        case MethodName.identify:
            handleIdentify(call, result: result, args: args)
        case MethodName.getPaywalls:
            handleGetPaywalls(call, result: result)
        case MethodName.makePurchase:
            handleMakePurchase(call, result: result, args: args)
        case MethodName.validateReceipt:
            handleValidateReceipt(call, result: result, args: args)
        case MethodName.restorePurchases:
            handleRestorePurchases(call, result: result)
        case MethodName.getPurchaserInfo:
            handleGetPurchaserInfo(call, result: result)
        case MethodName.getActivePurchases:
            handleGetActivePurchases(call, result: result, args: args)
        case MethodName.updateAttribution:
            handleUpdateAttribution(call, result: result, args: args)
        case MethodName.makeDeferredPurchase:
            handleMakeDeferredPurchase(call, result: result, args: args)
        case MethodName.getPromo:
            handleGetPromo(call, result: result)
        case MethodName.logout:
            handleLogout(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
            break
        }
    }

    // MARK: - Activate
    private func handleActivate(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let appKey = args[SwiftAdaptyFlutterConstants.appKey] as? String else  {
            result(false)
            return
        }

        if let customerUserId = args[SwiftAdaptyFlutterConstants.customerUserId] as? String {
            Adapty.activate(appKey, customerUserId: customerUserId)
        } else {
            Adapty.activate(appKey)
        }
        
        Adapty.delegate = self

        result(true)
    }
    
    // MARK: - Identify
    private func handleIdentify(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let customerUserId = args[SwiftAdaptyFlutterConstants.customerUserId] as? String else  {
            result(false)
            return
        }
        
        Adapty.identify(customerUserId) { (error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }
    
    // MARK: - Get Paywalls
    private func handleGetPaywalls(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.getPaywalls { (paywalls, products, state, error) in
            if let error = error {
                 result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                self.cachePaywalls(paywalls: paywalls)
                self.cacheProducts(products: products)

                do {
                    let getPaywallsResult = String(data: try JSONEncoder().encode(GetPaywallsResult(paywalls: self.paywallsIds(paywalls: paywalls ?? []), products: self.products(products: products ?? []))), encoding: .utf8)
                    
                    // stream
                    Self.channel?.invokeMethod(MethodName.getPaywallsResult.rawValue, arguments: getPaywallsResult)
                    
                    // result
                    result(getPaywallsResult)
                } catch {
                    result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode, message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Make Purchase
    private func handleMakePurchase(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let productId = args[SwiftAdaptyFlutterConstants.productId] as? String, let product = products[productId] else  {
            result(FlutterError(code: call.method, message: "No product id passed", details: nil))
            return
        }

        Adapty.makePurchase(product: product) { (purchaserInfo, receipt, appleValidationResult, product, error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                do {
                    result(String(data: try JSONEncoder().encode(MakePurchaseResult(receipt: receipt)), encoding: .utf8))
                } catch {
                    result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode, message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Validate Receipt
    private func handleValidateReceipt(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let receipt = args[SwiftAdaptyFlutterConstants.receipt] as? String else  {
            result(false)
            return
        }

        Adapty.validateReceipt(receipt) { (purchaserInfo, response, error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }

    // MARK: - Restore Purchases
    private func handleRestorePurchases(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.restorePurchases { (error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }

    // MARK: - Get Purchaser Info
    // TODO: not implemented
    private func handleGetPurchaserInfo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.getPurchaserInfo { (purchaserInfo, state, error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }

    // MARK: - Get Active Purchases
    private func handleGetActivePurchases(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        Adapty.getPurchaserInfo { (purchaserInfo, state, error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                var nonSubscriptionsIds = Set<String>()
                purchaserInfo?.nonSubscriptions.values.forEach { nonSubscriptions in
                    nonSubscriptions.forEach { info in
                        nonSubscriptionsIds.insert(info.vendorProductId)
                    }
                }

                let paidAccessLevel = args[SwiftAdaptyFlutterConstants.paidAccessLevel] as? String ?? ""
                let subscription = purchaserInfo?.paidAccessLevels[paidAccessLevel]
                
                do {
                    let getActivePurchasesResult = String(data: try JSONEncoder().encode(GetActivePurchasesResult(activeSubscription: subscription?.isActive ?? false, activeSubscriptionProductId: subscription?.vendorProductId, nonSubscriptionsProductIds: Array(nonSubscriptionsIds))), encoding: .utf8)
                    
                    // stream
                    Self.channel?.invokeMethod(MethodName.getActivePurchasesResult.rawValue, arguments: getActivePurchasesResult)
                    
                    // result
                    result(getActivePurchasesResult)
                } catch {
                    result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode, message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Update Attribution
    private func handleUpdateAttribution(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        if let attribution = args[SwiftAdaptyFlutterConstants.attribution] as? [AnyHashable: Any], let network = attributionNetwork(source: args[SwiftAdaptyFlutterConstants.source] as? String) {
            if let userId = args[SwiftAdaptyFlutterConstants.userId] as? String {
                Adapty.updateAttribution(attribution, source: network, networkUserId: userId)
            } else {
                Adapty.updateAttribution(attribution, source: network)
            }
            result(true)
        } else {
            result(false)
        }
    }
    
    // MARK: - Make Deferred
    private func handleMakeDeferredPurchase(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let productId = args[SwiftAdaptyFlutterConstants.productId] as? String else  {
            result(FlutterError(code: call.method, message: "No product id passed", details: nil))
            return
        }
        
        if let defferedPurchase = deferredPurchaseCompletion, productId == deferredPurchaseProductId {
            defferedPurchase { (purchaserInfo, receipt, response, product, error) in
                if let error = error {
                    result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
                } else {
                    self.deferredPurchaseCompletion = nil
                    self.deferredPurchaseProductId = nil
                    
                    do {
                        result(String(data: try JSONEncoder().encode(MakePurchaseResult(receipt: receipt)), encoding: .utf8))
                    } catch {
                        result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode, message: error.localizedDescription, details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: call.method, message: "No deferred purhase initiated", details: nil))
        }
    }
    
    // MARK: - Get Promo
    private func handleGetPromo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.getPromo { (promo, error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                if let adaptyPromo = self.adaptyPromo(promo: promo) {
                    do {
                        result(String(data: try JSONEncoder().encode(adaptyPromo), encoding: .utf8))
                    } catch {
                        result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode, message: error.localizedDescription, details: nil))
                    }
                } else {
                    result(FlutterError(code: call.method, message: "Promo model error", details: nil))
                }
            }
        }
    }
    
    // MARK: - Logout
    private func handleLogout(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.logout { (error) in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }

    private func cachePaywalls(paywalls: [PaywallModel]?) {
        self.paywalls.removeAll()
        self.paywalls.append(contentsOf: paywalls ?? [])
    }

    private func cacheProducts(products: [ProductModel]?) {
        self.products.removeAll()
        products?.forEach { product in
            self.products[product.vendorProductId] = product
        }
    }

    private func paywallsIds(paywalls: [PaywallModel?]) -> [String] {
        var ids = [String]()
        paywalls.forEach { paywall in
            if let id = paywall?.variationId {
                ids.append(id)
            }
        }
        return ids
    }

    private func products(products: [ProductModel?]) -> [AdaptyProduct] {
        var adaptyProducts = [AdaptyProduct]()
        products.forEach { product in
            if let id = product?.vendorProductId, let title = product?.localizedTitle, let description = product?.localizedDescription, let price = product?.price, let localizedPrice = product?.localizedPrice, let currency = product?.currencyCode {
                adaptyProducts.append(AdaptyProduct(id: id, title: title, description: description, price: String(describing: price), localizedPrice: localizedPrice, currency: currency))
            }
        }
        return adaptyProducts
    }

    private func attributionNetwork(source: String?) -> AttributionNetwork? {
        if let type = SourceType.init(rawValue: source ?? "") {
            switch type {
            case SourceType.adjust:
                return .adjust
            case SourceType.appsflyer:
                return .appsflyer
            case SourceType.branch:
                return .branch
            }
        } else {
            return nil
        }
    }
    
    private func adaptyPromo(promo: PromoModel?) -> AdaptyPromo? {
        if let id = promo?.variationId, let promoType = promo?.promoType, let paywallId = promo?.paywall?.variationId {
            return AdaptyPromo(id: id, promoType: promoType, expiresAt: Int64(promo?.expiresAt?.timeIntervalSince1970 ?? -1), paywallId: paywallId, paywallDeveloperId: promo?.paywall?.developerId ?? "",paywallProducts: products(products: promo?.paywall?.products ?? []))
        } else {
            return nil
        }
    }
}


extension SwiftAdaptyFlutterPlugin: AdaptyDelegate {
    
    public func didReceiveUpdatedPurchaserInfo(_ purchaserInfo: PurchaserInfoModel) {
        var nonSubscriptionsIds = Set<String>()
        purchaserInfo.nonSubscriptions.values.forEach { nonSubscriptions in
            nonSubscriptions.forEach { info in
                nonSubscriptionsIds.insert(info.vendorProductId)
            }
        }
        
        var activePaidAccessLevels = Set<String>()
        var activeSubscriptionsIds = Set<String>()
        purchaserInfo.paidAccessLevels.forEach { (id, paidAccessLevel) in
            if paidAccessLevel.isActive {
                activePaidAccessLevels.insert(id)
                activeSubscriptionsIds.insert(paidAccessLevel.vendorProductId)
            }
        }
        
        do {
            let updatedPurchaserInfo = String(data: try JSONEncoder().encode(UpdatedPurchaserInfo(nonSubscriptionsProductIds: Array(nonSubscriptionsIds), activePaidAccessLevels: Array(activePaidAccessLevels), activeSubscriptionsIds: Array(activeSubscriptionsIds))), encoding: .utf8)
            Self.channel?.invokeMethod(MethodName.purchaserInfoUpdate.rawValue, arguments: updatedPurchaserInfo)
        } catch {
            // do nothing
        }
    }
    
    public func didReceivePromo(_ promo: PromoModel) {
        if let adaptyPromo = adaptyPromo(promo: promo) {
            do {
                Self.channel?.invokeMethod(MethodName.promoReceived.rawValue, arguments: String(data: try JSONEncoder().encode(adaptyPromo), encoding: .utf8))
            } catch {
                // do nothing
            }
        }
    }
    
    public func paymentQueue(shouldAddStorePaymentFor product: ProductModel, defermentCompletion makeDeferredPurchase: @escaping DeferredPurchaseCompletion) {
        self.deferredPurchaseCompletion = makeDeferredPurchase
        self.deferredPurchaseProductId = product.vendorProductId
        
        Self.channel?.invokeMethod(MethodName.defferedPurchaseProduct.rawValue, arguments: product.vendorProductId)
    }
}
