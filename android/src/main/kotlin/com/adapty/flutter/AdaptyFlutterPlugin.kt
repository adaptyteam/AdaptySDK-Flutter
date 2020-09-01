package com.adapty.flutter

import android.app.Activity
import androidx.annotation.NonNull
import com.adapty.Adapty
import com.adapty.api.AttributionType
import com.adapty.api.entity.containers.DataContainer
import com.adapty.api.entity.containers.Product
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.adapty.flutter.extensions.safeLet
import com.adapty.flutter.models.AdaptyProduct
import com.adapty.flutter.models.GetActivePurchasesResult
import com.adapty.flutter.models.GetPaywallsResult
import com.adapty.flutter.models.MakePurchaseResult
import org.jetbrains.annotations.NotNull

class AdaptyFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "flutter.adapty.com/adapty"
    }

    private lateinit var channel: MethodChannel

    private var activity: Activity? = null
    private var methods = HashSet<String>()

    private var containers = ArrayList<DataContainer>()
    private var products = HashMap<String, Product>()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this);
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (!methods.contains(call.method)) {
            methods.add(call.method)
            when (call.method) {
                "activate" -> handleActivate(call, result)
                "get_paywalls" -> handleGetPaywalls(call, result)
                "make_purchase" -> handleMakePurchase(call, result)
                "validate_purchase" -> handleValidatePurchase(call, result)
                "restore_purchases" -> handleRestorePurchases(call, result)
                "get_purchaser_info" -> handleGetPurchaserInfo(call, result)
                "get_active_purchases" -> handleGetActivePurchases(call, result)
                "update_attribution" -> handleUpdateAttribution(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onDetachedFromActivity() {
        onNewActivityPluginBinding(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        onNewActivityPluginBinding(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onNewActivityPluginBinding(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onNewActivityPluginBinding(binding)
    }

    private fun onNewActivityPluginBinding(binding: ActivityPluginBinding?) = if (binding == null) {
        activity = null
    } else {
        activity = binding.activity
    }

    private fun handleActivate(@NonNull call: MethodCall, @NonNull result: Result) {
        val appKey: String = call.argument<String>("app_key") ?: ""
        val customerUserId: String = call.argument<String>("customer_user_id") ?: ""
        when {
            appKey.isBlank() -> resultIfNeeded(call) { result.success(false) }
            customerUserId.isBlank() -> {
                activity?.let {
                    Adapty.activate(it.applicationContext, appKey)
                    resultIfNeeded(call) { result.success(true) }
                } ?: resultIfNeeded(call) { result.success(false) }
            }
            else -> {
                activity?.let {
                    Adapty.activate(it.applicationContext, appKey, customerUserId)
                    resultIfNeeded(call) { result.success(true) }
                } ?: resultIfNeeded(call) { result.success(false) }
            }
        }
    }

    private fun handleGetPaywalls(@NonNull call: MethodCall, @NonNull result: Result) {
        activity?.let { activity ->
            Adapty.getPurchaseContainers(activity) { containers: ArrayList<DataContainer>, products: ArrayList<Product>, state: String, error: String? ->
                try {
                    error?.let {
                        resultIfNeeded(call) { result.error(call.method, it, null) }
                    } ?: run {
                        cachePaywalls(containers)
                        cacheProducts(products)

                        val getPaywallsResultJson = Gson().toJson(GetPaywallsResult(paywallsIds(containers), products(products)))
                        resultIfNeeded(call) { result.success(getPaywallsResultJson) }
                    }
                } catch (fe: FlutterException) {
                    resultIfNeeded(call) { result.error(call.method, fe.message, fe.localizedMessage) }
                }
            }
        } ?: resultIfNeeded(call) { result.success("") }
    }

    private fun handleMakePurchase(@NonNull call: MethodCall, @NonNull result: Result) {
        val productId: String = call.argument<String>("product_id") ?: ""
        safeLet(activity, products[productId]) { activity, product ->
            Adapty.makePurchase(activity, product) { purchase, response, error ->
                error?.let {
                    resultIfNeeded(call) { result.error(call.method, it, null) }
                } ?: run {
                    resultIfNeeded(call) { result.success(Gson().toJson(MakePurchaseResult(purchase?.purchaseToken, product.skuDetails?.type))) }
                }
            }
        } ?: resultIfNeeded(call) { result.error(call.method, "No product id passed", null) }
    }

    private fun handleValidatePurchase(@NonNull call: MethodCall, @NonNull result: Result) {
        val purchaseType: String = call.argument<String>("purchase_type") ?: ""
        val productId: String = call.argument<String>("product_id") ?: ""
        val purchaseToken: String = call.argument<String>("purchase_token") ?: ""

        if (purchaseType.isNotBlank() && productId.isNotBlank() && purchaseToken.isNotBlank()) {
            Adapty.validatePurchase(purchaseType, productId, purchaseToken) { response, error ->
                error?.let {
                    resultIfNeeded(call) { result.error(call.method, it, null) }
                } ?: resultIfNeeded(call) { result.success(true) }
            }
        } else {
            resultIfNeeded(call) { result.success(false) }
        }
    }

    private fun handleRestorePurchases(@NonNull call: MethodCall, @NonNull result: Result) {
        activity?.let { activity ->
            Adapty.restorePurchases(activity) { _, error ->
                error?.let {
                    resultIfNeeded(call) { result.error(call.method, it, null) }
                } ?: resultIfNeeded(call) { result.success(true) }
            }
        }
    }

    // TODO: not implemented
    private fun handleGetPurchaserInfo(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.getPurchaserInfo { _, _, error ->
            error?.let {
                resultIfNeeded(call) { result.error(call.method, it, null) }
            } ?: resultIfNeeded(call) {
                result.success(true)
            }
        }
    }

    private fun handleGetActivePurchases(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.getPurchaserInfo { purchaserInfo, _, error ->
            error?.let {
                resultIfNeeded(call) { result.error(call.method, it, null) }
            } ?: run {
                val nonSubscriptionsIds = ArrayList<String>()
                purchaserInfo?.nonSubscriptions?.values?.forEach { nonSubscriptions ->
                    nonSubscriptions.forEach { info ->
                        info.vendorProductId?.let { id -> nonSubscriptionsIds.add(id) }
                    }
                }

                val paidAccessLevel: String = call.argument<String>("paid_access_level") ?: ""
                if (paidAccessLevel.isNotBlank()) {
                    purchaserInfo?.paidAccessLevels?.get(paidAccessLevel)?.let { subscription ->
                        resultIfNeeded(call) {
                            result.success(Gson().toJson(GetActivePurchasesResult(subscription.isActive
                                    ?: false, subscription.vendorProductId, nonSubscriptionsIds)))
                        }
                    } ?: resultIfNeeded(call) {
                        result.success(Gson().toJson(GetActivePurchasesResult(false, null, nonSubscriptionsIds)))
                    }
                } else {
                    resultIfNeeded(call) { result.success(Gson().toJson(GetActivePurchasesResult(false, null, nonSubscriptionsIds))) }
                }
            }
        }
    }

    private fun handleUpdateAttribution(@NotNull call: MethodCall, @NotNull result: Result) {
        val attribution = call.argument<Map<String, String>>("attribution")
        val userId = call.argument<String>("user_id")
        val type = when (call.argument<String>("source")) {
            "adjust" -> AttributionType.ADJUST
            "appsflyer" -> AttributionType.APPSFLYER
            "branch" -> AttributionType.BRANCH
            else -> null
        }

        safeLet(attribution, type) { attr, source ->
            userId?.let { id ->
                Adapty.updateAttribution(attr, source, id)
            } ?: Adapty.updateAttribution(attr, source)

            resultIfNeeded(call) { result.success(true) }
        } ?: resultIfNeeded(call) {
            result.success(false)
        }
    }

    private fun cachePaywalls(containers: ArrayList<DataContainer>) = this.containers.run {
        clear()
        addAll(containers)
    }

    private fun cacheProducts(products: ArrayList<Product>) = this.products.run {
        clear()
        products.forEach { product ->
            product.vendorProductId?.let { id ->
                put(id, product)
            }
        }
    }

    private fun paywallsIds(containers: ArrayList<DataContainer>) = ArrayList<String>().apply {
        containers.forEach { container ->
            container.attributes?.variationId?.let { id ->
                add(id)
            }
        }
    }

    private fun products(products: ArrayList<Product>) = ArrayList<AdaptyProduct>().apply {
        products.forEach { product ->
            adaptyProduct(product)?.let { add(it) }
        }
    }

    private fun adaptyProduct(product: Product) = safeLet(product.vendorProductId,
            product.localizedTitle,
            product.localizedDescription,
            product.price,
            product.skuDetails?.price,
            product.skuDetails?.priceCurrencyCode) { id, title, description, price, localizedPrice, currencyCode ->
        AdaptyProduct(id, title, description, price, localizedPrice, currencyCode)
    }

    private inline fun resultIfNeeded(@NonNull call: MethodCall, inline: () -> Unit) {
        if (methods.contains(call.method)) {
            methods.remove(call.method)
            inline.invoke()
        }
    }
}
