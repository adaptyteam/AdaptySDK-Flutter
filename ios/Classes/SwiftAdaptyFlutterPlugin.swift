import Adapty
import Flutter

extension AdaptyProductsFetchPolicy {
    static func fromJSONValue(_ value: String) -> AdaptyProductsFetchPolicy {
        switch value {
        case "wait_for_receipt_validation":
            return .waitForReceiptValidation
        default:
            return .default
        }
    }
}

public class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()

    static var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        decoder.dataDecodingStrategy = .base64
        return decoder
    }()

    static var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        encoder.dataEncodingStrategy = .base64
        return encoder
    }()

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

        self.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()

        switch MethodName(rawValue: call.method) ?? .notImplemented {
        case .setLogLevel: handleSetLogLevel(call, result: result, args: args)
        case .setFallbackPaywalls: handleSetFallbackPaywalls(call, result, args)
        case .identify: handleIdentify(call, result: result, args: args)
        case .getPaywall: handleGetPaywall(call, result, args)
        case .getPaywallProducts: handleGetPaywallProducts(call, result, args)
        case .logShowPaywall: handleLogShowPaywall(call, result: result, args: args)
        case .makePurchase: handleMakePurchase(call, result, args)
        case .restorePurchases: handleRestorePurchases(call, result, args)
        case .getProfile: handleGetProfile(call, result, args)
        case .updateAttribution: handleUpdateAttribution(call, result: result, args: args)
        case .makeDeferredPurchase: handleMakeDeferredPurchase(call, result: result, args: args)
        case .logout: handleLogout(call, result: result)
        case .updateProfile: handleUpdateProfile(call, result, args)
        case .setTransactionVariationId: handleSetTransactionVariationId(call, result: result, args: args)
        case .presentCodeRedemptionSheet: handlePresentCodeRedemptionSheet(call, result: result, args: args)
        default:
            result(FlutterMethodNotImplemented)
        }
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

    // MARK: - Paywalls & Products

    private func handleGetPaywall(_ flutterCall: FlutterMethodCall,
                                  _ flutterResult: @escaping FlutterResult,
                                  _ args: [String: Any]) {
        guard let id = args[SwiftAdaptyFlutterConstants.id] as? String else {
            flutterCall.callParameterError(flutterResult, parameter: SwiftAdaptyFlutterConstants.id)
            return
        }

        Adapty.getPaywall(id) { result in
            switch result {
            case let .success(paywall):
                flutterCall.callResult(resultModel: paywall, result: flutterResult)
            case let .failure(error):
                flutterCall.callAdaptyError(flutterResult, error: error)
            }
        }
    }

    private func handleGetPaywallProducts(_ flutterCall: FlutterMethodCall,
                                          _ flutterResult: @escaping FlutterResult,
                                          _ args: [String: Any]) {
        guard let paywallString = args[SwiftAdaptyFlutterConstants.paywall] as? String,
              let paywallData = paywallString.data(using: .utf8),
              let paywall = try? Self.jsonDecoder.decode(AdaptyPaywall.self, from: paywallData) else {
            flutterCall.callParameterError(flutterResult, parameter: SwiftAdaptyFlutterConstants.paywall)
            return
        }

        guard let fetchPolicyJSON = args[SwiftAdaptyFlutterConstants.fetchPolicy] as? String else {
            flutterCall.callParameterError(flutterResult, parameter: SwiftAdaptyFlutterConstants.fetchPolicy)
            return
        }

        Adapty.getPaywallProducts(paywall: paywall, fetchPolicy: .fromJSONValue(fetchPolicyJSON)) { result in
            switch result {
            case let .success(products):
                flutterCall.callResult(resultModel: products, result: flutterResult)
            case let .failure(error):
                flutterCall.callAdaptyError(flutterResult, error: error)
            }
        }
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
                result(nil)
            }
        }
    }

    private func handleGetProfile(_ flutterCall: FlutterMethodCall,
                                  _ flutterResult: @escaping FlutterResult,
                                  _ args: [String: Any]) {
        Adapty.getProfile { result in
            switch result {
            case let .success(profile):
                flutterCall.callResult(resultModel: profile, result: flutterResult)
            case let .failure(error):
                flutterCall.callAdaptyError(flutterResult, error: error)
            }
        }
    }

    private func handleUpdateProfile(_ flutterCall: FlutterMethodCall,
                                     _ flutterResult: @escaping FlutterResult,
                                     _ args: [String: Any]) {
        guard let paramsString = args[SwiftAdaptyFlutterConstants.params] as? String,
              let paramsData = paramsString.data(using: .utf8),
              let params = try? Self.jsonDecoder.decode(AdaptyProfileParameters.self, from: paramsData) else {
            flutterCall.callParameterError(flutterResult, parameter: SwiftAdaptyFlutterConstants.paywall)
            return
        }
        
        Adapty.updateProfile(params: params) { error in
            if let error = error {
                flutterCall.callAdaptyError(flutterResult, error: error)
            } else {
                flutterResult(nil)
            }
        }
    }

    // MARK: - Make Purchase

    private func handleMakePurchase(_ flutterCall: FlutterMethodCall,
                                    _ flutterResult: @escaping FlutterResult,
                                    _ args: [String: Any]) {
        guard let productString = args[SwiftAdaptyFlutterConstants.product] as? String,
              let productData = productString.data(using: .utf8) else {
            flutterCall.callParameterError(flutterResult, parameter: SwiftAdaptyFlutterConstants.product)
            return
        }

        Adapty.getPaywallProduct(from: Self.jsonDecoder, data: productData) { result in
            switch result {
            case let .success(product):
                Adapty.makePurchase(product: product) { result in
                    switch result {
                    case let .success(profile):
                        flutterCall.callResult(resultModel: profile, result: flutterResult)
                    case let .failure(error):
                        flutterCall.callAdaptyError(flutterResult, error: error)
                    }
                }
            case let .failure(error):
                flutterCall.callAdaptyError(flutterResult, error: error)
            }
        }
    }

    // MARK: - Restore Purchases

    private func handleRestorePurchases(_ flutterCall: FlutterMethodCall,
                                        _ flutterResult: @escaping FlutterResult,
                                        _ args: [String: Any]) {
        Adapty.restorePurchases { result in
            switch result {
            case let .success(profile):
                flutterCall.callResult(resultModel: profile, result: flutterResult)
            case let .failure(error):
                flutterCall.callAdaptyError(flutterResult, error: error)
            }
        }
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

    private func handleSetFallbackPaywalls(_ flutterCall: FlutterMethodCall,
                                           _ flutterResult: @escaping FlutterResult,
                                           _ args: [String: Any]) {
        guard let paywallsString = args[SwiftAdaptyFlutterConstants.paywalls] as? String,
              let paywallsData = paywallsString.data(using: .utf8) else {
            flutterCall.callParameterError(flutterResult, parameter: SwiftAdaptyFlutterConstants.paywalls)
            return
        }

        Adapty.setFallbackPaywalls(paywallsData) { error in
            if let error = error {
                flutterCall.callAdaptyError(flutterResult, error: error)
            } else {
                flutterResult(nil)
            }
        }
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
        guard let data = try? JSONEncoder().encode(profile) else { return }
        Self.channel?.invokeMethod(MethodName.didUpdateProfile.rawValue, arguments: String(data: data, encoding: .utf8))
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
    @discardableResult
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
