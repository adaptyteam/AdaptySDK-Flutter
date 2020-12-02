import Adapty
import Flutter

public class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
    fileprivate static var jsonEncoder = JSONEncoder()
    private static var channel: FlutterMethodChannel?

    private var paywalls = [PaywallModel]()
    private var products = [ProductModel]()

    private var deferredPurchaseCompletion: DeferredPurchaseCompletion?
    private var deferredPurchaseProductId: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: SwiftAdaptyFlutterConstants.channelName, binaryMessenger: registrar.messenger())
        let instance = SwiftAdaptyFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)

        Adapty.delegate = instance
        SwiftAdaptyFlutterPlugin.jsonEncoder.dateEncodingStrategy = .millisecondsSince1970

        self.channel = channel
    }

    public static func handlePushNotification(_ userInfo: [AnyHashable: Any], completion: @escaping ErrorCompletion) {
        Adapty.handlePushNotification(userInfo, completion: completion)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        switch MethodName(rawValue: call.method) ?? .notImplemented {
        case .activate:
            handleActivate(call, result: result, args: args)
        case .identify:
            handleIdentify(call, result: result, args: args)
        case .getPaywalls:
            handleGetPaywalls(call, result: result)
        case .makePurchase:
            handleMakePurchase(call, result: result, args: args)
        case .validateReceipt:
            handleValidateReceipt(call, result: result, args: args)
        case .restorePurchases:
            handleRestorePurchases(call, result: result)
        case .getPurchaserInfo:
            handleGetPurchaserInfo(call, result: result)
        case .updateAttribution:
            handleUpdateAttribution(call, result: result, args: args)
        case .makeDeferredPurchase:
            handleMakeDeferredPurchase(call, result: result, args: args)
        case .getPromo:
            handleGetPromo(call, result: result)
        case .logout:
            handleLogout(call, result: result)
        case .getLogLevel:
            handleGetLogLevel(call, result: result)
        case .setLogLevel:
            handleSetLogLevel(call, result: result, args: args)
        case .updateProfile:
            handleUpdateProfile(call, result: result, args: args)
        case .setFallbackPaywalls:
            handleSetFallbackPaywalls(call, result: result, args: args)
        case .setApnsToken:
            handleSetApnsToken(call, result: result, args: args)
        case .handlePushNotification:
            handlePushNotification(call, result: result, args: args)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: – LogLevel

    private func handleGetLogLevel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        _ = call.callResult(resultModel: Adapty.logLevel, result: result)
    }

    private func handleSetLogLevel(_ call: FlutterMethodCall,
                                   result: @escaping FlutterResult,
                                   args: [String: Any]?) {
        guard let intValue = args?[SwiftAdaptyFlutterConstants.value] as? Int,
              let logLevel = AdaptyLogLevel(rawValue: intValue) else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.value)
            return
        }

        Adapty.logLevel = logLevel
        result(true)
    }

    // MARK: - Activate

    private func handleActivate(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]?) {
        guard let appKey = args?[SwiftAdaptyFlutterConstants.appKey] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.appKey)
            return
        }

        let observerMode = args?[SwiftAdaptyFlutterConstants.observerMode] as? Bool
        let customerUserId = args?[SwiftAdaptyFlutterConstants.customerUserId] as? String

        Adapty.logLevel = .verbose
        Adapty.activate(appKey,
                        observerMode: observerMode ?? false,
                        customerUserId: customerUserId)
        result(true)
    }

    // MARK: - Identify & Profile

    private func handleIdentify(_ call: FlutterMethodCall,
                                result: @escaping FlutterResult,
                                args: [String: Any]) {
        guard let customerUserId = args[SwiftAdaptyFlutterConstants.customerUserId] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.customerUserId)
            return
        }

        Adapty.identify(customerUserId) { error in
            if let error = error {
                call.callAdaptyError(result, error: error)
            } else {
                result(true)
            }
        }
    }

    private func handleUpdateProfile(_ call: FlutterMethodCall,
                                     result: @escaping FlutterResult,
                                     args: [String: Any]) {
        guard let params = args[SwiftAdaptyFlutterConstants.params] as? [String: Any] else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.customerUserId)
            return
        }

        let profuleBuilder = SwiftAdaptyProfileBuilder.createBuilder(map: params)

        Adapty.updateProfile(params: profuleBuilder) { error in
            if let error = error {
                call.callAdaptyError(result, error: error)
            } else {
                result(true)
            }
        }
    }

    // MARK: - Get Paywalls

    private func handleGetPaywalls(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.getPaywalls { [weak self] paywalls, products, _, error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            self?.cachePaywalls(paywalls)
            self?.cacheProducts(products)

            do {
                let getPaywallsResult = GetPaywallsResult(paywalls: paywalls,
                                                          products: products)
                let resultString = String(data: try JSONEncoder().encode(getPaywallsResult), encoding: .utf8)

                // stream
                Self.channel?.invokeMethod(MethodName.getPaywallsResult.rawValue, arguments: resultString)

                // result
                result(resultString)
            } catch {
                call.callEncodeError(result, error: error)
            }
        }
    }

    // MARK: - Make Purchase

    private func handleMakePurchase(_ call: FlutterMethodCall,
                                    result: @escaping FlutterResult, args: [String: Any]) {
        let variationId = args[SwiftAdaptyFlutterConstants.variationId] as? String

        guard let productId = args[SwiftAdaptyFlutterConstants.productId] as? String,
              let product = findProduct(productId: productId, variationId: variationId) else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.productId)
            return
        }

        Adapty.makePurchase(product: product) { purchaserInfo, receipt, _, product, error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            let purchaseResult = MakePurchaseResult(purchaserInfo: purchaserInfo,
                                                    receipt: receipt,
                                                    product: product)

            _ = call.callResult(resultModel: purchaseResult, result: result)
        }
    }

    // MARK: - Validate Receipt

    private func handleValidateReceipt(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let receipt = args[SwiftAdaptyFlutterConstants.receipt] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.receipt)
            return
        }

        Adapty.validateReceipt(receipt) { _, _, error in
            if let error = error {
                result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }

    // MARK: - Restore Purchases

    private func handleRestorePurchases(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.restorePurchases { purchaserInfo, receipt, _, error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            let restoreResult = RestorePurchasesResult(purchaserInfo: purchaserInfo,
                                                       receipt: receipt)

            _ = call.callResult(resultModel: restoreResult, result: result)
        }
    }

    // MARK: - Get Purchaser Info

    private func handleGetPurchaserInfo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.getPurchaserInfo { purchaserInfo, dataState, error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            let resultStruct = GetPurchaserInfoResult(purchaserInfo: purchaserInfo,
                                                      dataState: dataState)

            if let resultString = call.callResult(resultModel: resultStruct, result: result) {
                Self.channel?.invokeMethod(MethodName.getPurchaserInfo.rawValue,
                                           arguments: resultString)
            }
        }
    }

    // MARK: - Update Attribution

    private func handleUpdateAttribution(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let attribution = args[SwiftAdaptyFlutterConstants.attribution] as? [AnyHashable: Any] else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.attribution)
            return
        }
        guard let sourceString = args[SwiftAdaptyFlutterConstants.source] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.source)
            return
        }

        let networkUserId = args[SwiftAdaptyFlutterConstants.networkUserId] as? String

        Adapty.updateAttribution(attribution,
                                 source: AttributionNetwork.fromString(sourceString),
                                 networkUserId: networkUserId) { error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            result(true)
        }
    }

    // MARK: - Set Fallback Paywalls

    private func handleSetFallbackPaywalls(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let paywalls = args[SwiftAdaptyFlutterConstants.paywalls] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.paywalls)
            return
        }

        Adapty.setFallbackPaywalls(paywalls) { error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }
            result(true)
        }
    }

    // MARK: - Make Deferred

    private func handleMakeDeferredPurchase(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let productId = args[SwiftAdaptyFlutterConstants.productId] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.productId)
            return
        }

        if let defferedPurchase = deferredPurchaseCompletion, productId == deferredPurchaseProductId {
            defferedPurchase { purchaserInfo, receipt, _, product, error in
                if let error = error {
                    result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
                } else {
                    self.deferredPurchaseCompletion = nil
                    self.deferredPurchaseProductId = nil

                    do {
                        let purchaseResult = MakePurchaseResult(purchaserInfo: purchaserInfo,
                                                                receipt: receipt,
                                                                product: product)

                        result(String(data: try JSONEncoder().encode(purchaseResult), encoding: .utf8))
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
        Adapty.getPromo { promo, error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            if let promo = promo {
                _ = call.callResult(resultModel: promo, result: result)
            } else {
                result(nil)
            }
        }
    }

    // MARK: - Set Apns Token

    private func handleSetApnsToken(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let value = args[SwiftAdaptyFlutterConstants.value] as? String,
              let utf8Str = value.data(using: .utf8) else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.value)
            return
        }

        let base64Encoded = utf8Str.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
        Adapty.apnsToken = Data(base64Encoded: base64Encoded)

        result(nil)
    }

    // MARK: - Set Apns Token

    private func handlePushNotification(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let userInfo = args[SwiftAdaptyFlutterConstants.userInfo] as? [AnyHashable: Any] else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.userInfo)
            return
        }

        Adapty.handlePushNotification(userInfo) { error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            result(nil)
        }
    }

    // MARK: - Logout

    private func handleLogout(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.logout { error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            result(true)
        }
    }

    private func cachePaywalls(_ paywalls: [PaywallModel]?) {
        self.paywalls.removeAll()
        if let paywalls = paywalls {
            self.paywalls.append(contentsOf: paywalls)
        }
    }

    private func cacheProducts(_ products: [ProductModel]?) {
        self.products.removeAll()
        if let products = products {
            self.products.append(contentsOf: products)
        }
    }

    private func findProduct(productId: String, variationId: String?) -> ProductModel? {
        guard let variationId = variationId,
              let paywall = paywalls.first(where: { $0.variationId == variationId }) else {
            return products.first(where: { $0.vendorProductId == productId })
        }

        return paywall.products.first(where: { $0.vendorProductId == productId })
    }
}

extension SwiftAdaptyFlutterPlugin: AdaptyDelegate {
    public func didReceiveUpdatedPurchaserInfo(_ purchaserInfo: PurchaserInfoModel) {
        guard let data = try? JSONEncoder().encode(purchaserInfo) else { return }
        Self.channel?.invokeMethod(MethodName.purchaserInfoUpdate.rawValue, arguments: String(data: data, encoding: .utf8))
    }

    public func didReceivePromo(_ promo: PromoModel) {
        guard let data = try? JSONEncoder().encode(promo) else { return }
        Self.channel?.invokeMethod(MethodName.promoReceived.rawValue, arguments: String(data: data, encoding: .utf8))
    }

    public func paymentQueue(shouldAddStorePaymentFor product: ProductModel, defermentCompletion makeDeferredPurchase: @escaping DeferredPurchaseCompletion) {
        deferredPurchaseCompletion = makeDeferredPurchase
        deferredPurchaseProductId = product.vendorProductId

        Self.channel?.invokeMethod(MethodName.defferedPurchaseProduct.rawValue, arguments: product.vendorProductId)
    }
}

extension FlutterMethodCall {
    func callResult<T: Encodable>(resultModel: T, result: @escaping FlutterResult) -> String? {
        do {
            let resultString = String(data: try SwiftAdaptyFlutterPlugin.jsonEncoder.encode(resultModel),
                                      encoding: .utf8)
            result(resultString)
            return resultString
        } catch {
            callEncodeError(result, error: error)
            return nil
        }
    }

    func callParameterError(_ result: FlutterResult, parameter: String) {
        result(FlutterError(code: method,
                            message: "Error while parsing parameter \(parameter)",
                            details: nil))
    }

    func callEncodeError(_ result: FlutterResult, error: Error) {
        result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode,
                            message: error.localizedDescription,
                            details: nil))
    }

    func callAdaptyError(_ result: FlutterResult, error: AdaptyError) {
        do {
            let adaptyErrorString = String(data: try SwiftAdaptyFlutterPlugin.jsonEncoder.encode(error),
                                           encoding: .utf8)
            result(FlutterError(code: method, message: error.localizedDescription, details: adaptyErrorString))
        } catch {
            result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode,
                                message: error.localizedDescription,
                                details: nil))
        }
    }
}
