import Adapty
import Flutter

public class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
    fileprivate static var jsonEncoder = JSONEncoder()
    private static var channel: FlutterMethodChannel?
    private static let pluginInstance = SwiftAdaptyFlutterPlugin()

//    private var paywalls = [PaywallModel]()
//    private var products = [ProductModel]()

//    private var deferredPurchaseCompletion: DeferredPurchaseCompletion?
//    private var deferredPurchaseProductId: String?

    private var infoDictionary: [String: Any]? {
        guard let plistPath = Bundle.main.path(forResource: "Adapty-Info", ofType: "plist"),
              let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData,
                                                                      options: .mutableContainers,
                                                                      format: nil) as? [String: Any]? else {
            return Bundle.main.infoDictionary
        }

        return plist
    }

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]) -> Bool {
        activateOnLaunch()
        return true
    }

    private func activateOnLaunch() {
        guard let infoDictionary = infoDictionary,
              let apiKey = infoDictionary["AdaptyPublicSdkKey"] as? String else {
            print("[Adapty-Flutter] you must provide 'AdaptyPublicSdkKey' in your application Adapty-Info.plist file to initialize Adapty")
            return
        }

        Adapty.delegate = SwiftAdaptyFlutterPlugin.pluginInstance

        let observerMode = infoDictionary["AdaptyObserverMode"] as? Bool ?? false

        Adapty.idfaCollectionDisabled = infoDictionary["AdaptyIDFACollectionDisabled"] as? Bool ?? false
        Adapty.activate(apiKey, observerMode: observerMode)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: SwiftAdaptyFlutterConstants.channelName, binaryMessenger: registrar.messenger())

        registrar.addMethodCallDelegate(pluginInstance, channel: channel)
        registrar.addApplicationDelegate(pluginInstance)

        SwiftAdaptyFlutterPlugin.jsonEncoder.dateEncodingStrategy = .custom({ date, encoder in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let stringData = formatter.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(stringData)
        })

        self.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        switch MethodName(rawValue: call.method) ?? .notImplemented {
        case .identify:
            handleIdentify(call, result: result, args: args)
//        case .getPaywalls:
//            handleGetPaywalls(call, result: result, args: args)
        case .makePurchase:
            handleMakePurchase(call, result: result, args: args)
        case .restorePurchases:
            handleRestorePurchases(call, result: result)
        case .getPurchaserInfo:
            handleGetPurchaserInfo(call, result: result, args: args)
        case .updateAttribution:
            handleUpdateAttribution(call, result: result, args: args)
        case .makeDeferredPurchase:
            handleMakeDeferredPurchase(call, result: result, args: args)
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
        case .logShowPaywall:
            handleLogShowPaywall(call, result: result, args: args)
        case .setExternalAnalyticsEnabled:
            handleSetExternalAnalyticsEnabled(call, result: result, args: args)
        case .setTransactionVariationId:
            handleSetTransactionVariationId(call, result: result, args: args)
        case .presentCodeRedemptionSheet:
            handlePresentCodeRedemptionSheet(call, result: result, args: args)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: – LogLevel

    private func handleGetLogLevel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(Adapty.logLevel.rawValue)
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
        result(FlutterMethodNotImplemented)
//        guard let params = args[SwiftAdaptyFlutterConstants.params] as? [String: Any] else {
//            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.customerUserId)
//            return
//        }
//
//        let profuleBuilder = SwiftAdaptyProfileBuilder.createBuilder(map: params)
//
//        Adapty.updateProfile(params: profuleBuilder) { error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//            } else {
//                result(true)
//            }
//        }
    }

    // MARK: - Make Purchase

    private func handleMakePurchase(_ call: FlutterMethodCall,
                                    result: @escaping FlutterResult, args: [String: Any]) {
        result(FlutterMethodNotImplemented)
//        let variationId = args[SwiftAdaptyFlutterConstants.variationId] as? String
//
//        guard let productId = args[SwiftAdaptyFlutterConstants.productId] as? String,
//              let product = findProduct(productId: productId, variationId: variationId) else {
//            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.productId)
//            return
//        }
//
//        let offerId = args[SwiftAdaptyFlutterConstants.offerId] as? String
//
//        Adapty.makePurchase(product: product, offerId: offerId) { purchaserInfo, receipt, _, product, error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//                return
//            }
//
//            let purchaseResult = MakePurchaseResult(purchaserInfo: purchaserInfo,
//                                                    receipt: receipt,
//                                                    product: product)
//
//            _ = call.callResult(resultModel: purchaseResult, result: result)
//        }
    }

    // MARK: - Restore Purchases

    private func handleRestorePurchases(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterMethodNotImplemented)
//        Adapty.restorePurchases { purchaserInfo, receipt, _, error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//                return
//            }
//
//            let restoreResult = RestorePurchasesResult(purchaserInfo: purchaserInfo, receipt: receipt, errorString: nil)
//            _ = call.callResult(resultModel: restoreResult, result: result)
//        }
    }

    // MARK: - Get Purchaser Info

    private func handleGetPurchaserInfo(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        result(FlutterMethodNotImplemented)
//        let forceUpdate = args[SwiftAdaptyFlutterConstants.forceUpdate] as? Bool ?? false
//
//        Adapty.getPurchaserInfo(forceUpdate: forceUpdate) { purchaserInfo, error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//                return
//            }
//
//            guard let purchaserInfo = purchaserInfo else {
//                result(nil)
//                return
//            }
//
//            _ = call.callResult(resultModel: purchaserInfo, result: result)
//        }
    }

    // MARK: - Update Attribution

    private func handleUpdateAttribution(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        result(FlutterMethodNotImplemented)
//        guard let attribution = args[SwiftAdaptyFlutterConstants.attribution] as? [AnyHashable: Any] else {
//            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.attribution)
//            return
//        }
//        guard let sourceString = args[SwiftAdaptyFlutterConstants.source] as? String else {
//            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.source)
//            return
//        }
//
//        let networkUserId = args[SwiftAdaptyFlutterConstants.networkUserId] as? String
//
//        Adapty.updateAttribution(attribution,
//                                 source: AttributionNetwork.fromString(sourceString),
//                                 networkUserId: networkUserId) { error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//                return
//            }
//
//            result(true)
//        }
    }

    // MARK: - Set Fallback Paywalls

    private func handleSetFallbackPaywalls(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        result(FlutterMethodNotImplemented)
//        guard let paywalls = args[SwiftAdaptyFlutterConstants.paywalls] as? String else {
//            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.paywalls)
//            return
//        }
//
//        Adapty.setFallbackPaywalls(paywalls) { error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//                return
//            }
//            result(true)
//        }
    }

    // MARK: - Make Deferred

    private func handleMakeDeferredPurchase(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        result(FlutterMethodNotImplemented)
//        guard let productId = args[SwiftAdaptyFlutterConstants.productId] as? String else {
//            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.productId)
//            return
//        }
//
//        if let deferredPurchase = deferredPurchaseCompletion, productId == deferredPurchaseProductId {
//            deferredPurchase { purchaserInfo, receipt, _, product, error in
//                if let error = error {
//                    result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
//                } else {
//                    self.deferredPurchaseCompletion = nil
//                    self.deferredPurchaseProductId = nil
//
//                    do {
//                        let purchaseResult = MakePurchaseResult(purchaserInfo: purchaserInfo,
//                                                                receipt: receipt,
//                                                                product: product)
//
//                        result(String(data: try JSONEncoder().encode(purchaseResult), encoding: .utf8))
//                    } catch {
//                        result(FlutterError(code: SwiftAdaptyFlutterConstants.jsonEncode, message: error.localizedDescription, details: nil))
//                    }
//                }
//            }
//        } else {
//            result(FlutterError(code: call.method, message: "No deferred purhase initiated", details: nil))
//        }
    }

    private func handleLogShowPaywall(_ call: FlutterMethodCall,
                                      result: @escaping FlutterResult,
                                      args: [String: Any]) {
        result(FlutterMethodNotImplemented)
//        let variationId = args[SwiftAdaptyFlutterConstants.variationId] as? String
//
//        guard let paywall = paywalls.first(where: { $0.variationId == variationId }) else {
//            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.variationId)
//            return
//        }
//
//        Adapty.logShowPaywall(paywall) { error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//                return
//            }
//
//            result(nil)
//        }
    }

    private func handleSetExternalAnalyticsEnabled(_ call: FlutterMethodCall,
                                                   result: @escaping FlutterResult,
                                                   args: [String: Any]) {
        result(FlutterMethodNotImplemented)
//        let enabled = args[SwiftAdaptyFlutterConstants.value] as? Bool
//
//        Adapty.setExternalAnalyticsEnabled(enabled ?? false) { error in
//            if let error = error {
//                call.callAdaptyError(result, error: error)
//                return
//            }
//
//            result(nil)
//        }
    }

    private func handleSetTransactionVariationId(_ call: FlutterMethodCall,
                                                 result: @escaping FlutterResult,
                                                 args: [String: Any]) {
        guard let variationId = args[SwiftAdaptyFlutterConstants.variationId] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.variationId)
            return
        }

        guard let transactionId = args[SwiftAdaptyFlutterConstants.transactionId] as? String else {
            call.callParameterError(result, parameter: SwiftAdaptyFlutterConstants.transactionId)
            return
        }

        Adapty.setVariationId(variationId, forTransactionId: transactionId) { error in
            if let error = error {
                call.callAdaptyError(result, error: error)
                return
            }

            result(nil)
        }
    }

    private func handlePresentCodeRedemptionSheet(_ call: FlutterMethodCall,
                                                  result: @escaping FlutterResult,
                                                  args: [String: Any]) {
        Adapty.presentCodeRedemptionSheet()
        result(nil)
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
}

extension SwiftAdaptyFlutterPlugin: AdaptyDelegate {
    public func didLoadLatestProfile(_ profile: AdaptyProfile) {
        // TODO: send to Flutter
    }
    
//    public func didReceiveUpdatedPurchaserInfo(_ purchaserInfo: PurchaserInfoModel) {
//        guard let data = try? JSONEncoder().encode(purchaserInfo) else { return }
//        Self.channel?.invokeMethod(MethodName.purchaserInfoUpdate.rawValue, arguments: String(data: data, encoding: .utf8))
//    }
//
//    public func didReceivePromo(_ promo: PromoModel) {
//        guard let data = try? JSONEncoder().encode(promo) else { return }
//        Self.channel?.invokeMethod(MethodName.promoReceived.rawValue, arguments: String(data: data, encoding: .utf8))
//    }
//
//    public func paymentQueue(shouldAddStorePaymentFor product: ProductModel, defermentCompletion makeDeferredPurchase: @escaping DeferredPurchaseCompletion) {
//        deferredPurchaseCompletion = makeDeferredPurchase
//        deferredPurchaseProductId = product.vendorProductId
//
//        Self.channel?.invokeMethod(MethodName.deferredPurchaseProduct.rawValue, arguments: product.vendorProductId)
//    }
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
