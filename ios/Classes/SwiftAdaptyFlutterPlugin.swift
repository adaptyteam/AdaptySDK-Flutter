import Flutter
import Adapty

public class SwiftAdaptyFlutterPlugin: NSObject, FlutterPlugin {

    private var paywalls = [PaywallModel?]()
    private var products = [String: ProductModel]()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter.adapty.com/adapty", binaryMessenger: registrar.messenger())
        let instance = SwiftAdaptyFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]()
        switch call.method {
        case "activate":
            handleActivate(call, result: result, args: args)
        case "get_paywalls":
            handleGetPaywalls(call, result: result)
        case "make_purchase":
            handleMakePurchase(call, result: result, args: args)
        case "validate_receipt":
            handleValidateReceipt(call, result: result, args: args)
        case "restore_purchases":
            handleRestorePurchases(call, result: result)
        case "get_purchaser_info":
            handleGetPurchaserInfo(call, result: result)
        case "get_active_purchases":
            handleGetActivePurchases(call, result: result, args: args)
        case "update_attribution":
            handleUpdateAttribution(call, result: result, args: args)
        default:
            break
        }
    }

    // MARK: - Activate
    private func handleActivate(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let appKey = args["app_key"] as? String else  {
            result(false)
            return
        }

        if let customerUserId = args["customer_user_id"] as? String {
            Adapty.activate(appKey, customerUserId: customerUserId)
        } else {
            Adapty.activate(appKey)
        }

        result(true)
    }

    // MARK: - Make Purchase
    private func handleMakePurchase(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let productId = args["product_id"] as? String, let product = products[productId] else  {
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
                    result(FlutterError(code: "json_encode", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Validate Receipt
    private func handleValidateReceipt(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        guard let receipt = args["receipt"] as? String else  {
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

    // MARK: - Get Paywalls
    private func handleGetPaywalls(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Adapty.getPaywalls {(paywalls, products, state, error) in
            if let error = error {
                 result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
            } else {
                self.cachePaywalls(paywalls: paywalls)
                self.cacheProducts(products: products)

                do {
                    result(String(data: try JSONEncoder().encode(GetPaywallsResult(paywalls: self.paywallsIds(paywalls: paywalls ?? []), products: self.products(products: products ?? []))), encoding: .utf8))
                } catch {
                    result(FlutterError(code: "json_encode", message: error.localizedDescription, details: nil))
                }
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
                var nonSubscriptionsIds = [String]()
                purchaserInfo?.nonSubscriptions.values.forEach { nonSubscriptions in
                    nonSubscriptions.forEach { info in
                        nonSubscriptionsIds.append(info.vendorProductId)
                    }
                }

                if let paidAccessLevel = args["paid_access_level"] as? String, let subscription = purchaserInfo?.paidAccessLevels[paidAccessLevel] {
                    self.encodeGetActivePurchasesResult(result: result, getActivePurchasesResult:
                        GetActivePurchasesResult(activeSubscription: subscription.isActive, activeSubscriptionProductId: subscription.vendorProductId, nonSubscriptionsProductIds: nonSubscriptionsIds))
                } else {
                    self.encodeGetActivePurchasesResult(result: result, getActivePurchasesResult: GetActivePurchasesResult(activeSubscription: false, activeSubscriptionProductId: nil, nonSubscriptionsProductIds: nonSubscriptionsIds))
                }
            }
        }
    }

    // MARK: - Update Attribution
    private func handleUpdateAttribution(_ call: FlutterMethodCall, result: @escaping FlutterResult, args: [String: Any]) {
        if let attribution = args["attribution"] as? [AnyHashable: Any], let network = attributionNetwork(source: args["source"] as? String) {
            if let userId = args["user_id"] as? String {
                Adapty.updateAttribution(attribution, source: network, networkUserId: userId)
            } else {
                Adapty.updateAttribution(attribution, source: network)
            }
            result(true)
        } else {
            result(false)
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

    private func encodeGetActivePurchasesResult(result: @escaping FlutterResult, getActivePurchasesResult: GetActivePurchasesResult) {
        do {
            result(String(data: try JSONEncoder().encode(getActivePurchasesResult), encoding: .utf8))
        } catch {
            result(FlutterError(code: "json_encode", message: error.localizedDescription, details: nil))
        }
    }

    private func attributionNetwork(source: String?) -> AttributionNetwork? {
        switch source {
        case "adjust":
            return .adjust
        case "appsflyer":
            return .appsflyer
        case "branch":
            return .branch
        default:
            return nil;
        }
    }
}
