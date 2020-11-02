package com.adapty.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import com.adapty.Adapty
import com.adapty.api.AttributionType
import com.adapty.api.entity.containers.DataContainer
import com.adapty.api.entity.containers.OnPromoReceivedListener
import com.adapty.api.entity.containers.Product
import com.adapty.api.entity.containers.Promo
import com.adapty.api.entity.purchaserInfo.OnPurchaserInfoUpdatedListener
import com.adapty.api.entity.purchaserInfo.model.PurchaserInfoModel
import com.adapty.flutter.constants.*
import com.adapty.flutter.extensions.safeLet
import com.adapty.flutter.extensions.toTimestamp
import com.adapty.flutter.models.*
import com.adapty.flutter.push.AdaptyFlutterPushHandler
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.jetbrains.annotations.NotNull
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
import kotlin.collections.HashSet

class AdaptyFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    companion object {

        fun registerWith(registrar: PluginRegistry.Registrar) {
            val instance = AdaptyFlutterPlugin();
            instance.activity = registrar.activity()
            instance.onAttachedToEngine(registrar.context(), registrar.messenger())
        }

        fun handleIntent(intent: Intent) = Adapty.handlePromoIntent(intent) { _, _ ->
            // do nothing
        }
    }

    private lateinit var channel: MethodChannel

    private var activity: Activity? = null
    private var results = HashSet<Int>()

    private var paywalls = ArrayList<DataContainer>()
    private var products = HashMap<String, Product>()

    private var pushHandler: AdaptyFlutterPushHandler? = null


    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(flutterPluginBinding.applicationContext, flutterPluginBinding.binaryMessenger)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (!results.contains(result.hashCode())) {
            results.add(result.hashCode())
            when (MethodName.fromValue(call.method)) {
                MethodName.ACTIVATE -> handleActivate(call, result)
                MethodName.IDENTIFY -> handleIdentify(call, result)
                MethodName.GET_PAYWALLS -> handleGetPaywalls(call, result)
                MethodName.MAKE_PURCHASE -> handleMakePurchase(call, result)
                MethodName.VALIDATE_PURCHASE -> handleValidatePurchase(call, result)
                MethodName.RESTORE_PURCHASES -> handleRestorePurchases(call, result)
                MethodName.GET_PURCHASER_INFO -> handleGetPurchaserInfo(call, result)
                MethodName.GET_ACTIVE_PURCHASES -> handleGetActivePurchases(call, result)
                MethodName.UPDATE_ATTRIBUTION -> handleUpdateAttribution(call, result)
                MethodName.MAKE_DEFERRED_PURCHASE -> resultIfNeeded(result) { result.error(call.method, "Not implemented", null) }
                MethodName.GET_PROMO -> handleGetPromo(call, result)
                MethodName.NEW_PUSH_TOKEN -> handleNewPushToken(call, result)
                MethodName.PUSH_RECEIVED -> handlePushReceived(call, result)
                MethodName.LOGOUT -> handleLogout(call, result)
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

    private fun onAttachedToEngine(context: Context, binaryMessenger: BinaryMessenger) {
        channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        pushHandler = AdaptyFlutterPushHandler(context)
    }

    private fun onNewActivityPluginBinding(binding: ActivityPluginBinding?) = if (binding == null) {
        activity = null
    } else {
        activity = binding.activity
    }

    private fun handleActivate(@NonNull call: MethodCall, @NonNull result: Result) {
        activity?.let {
            val appKey: String = call.argument<String>(APP_KEY) ?: ""
            val customerUserId: String = call.argument<String>(CUSTOMER_USER_ID) ?: ""
            when {
                appKey.isBlank() -> resultIfNeeded(result) { result.success(false) }
                customerUserId.isBlank() -> {
                    Adapty.activate(it.applicationContext, appKey)
                    resultIfNeeded(result) { result.success(true) }
                }
                else -> {
                    Adapty.activate(it.applicationContext, appKey, customerUserId)
                    resultIfNeeded(result) { result.success(true) }
                }
            }

            listenPurchaserInfoUpdates()
            listenPromoUpdates()
        } ?: resultIfNeeded(result) { result.success(false) }
    }

    private fun handleIdentify(@NonNull call: MethodCall, @NonNull result: Result) {
        val customerUserId: String = call.argument<String>(CUSTOMER_USER_ID) ?: ""
        if (customerUserId.isNotBlank()) {
            Adapty.identify(customerUserId) { error ->
                error?.let {
                    resultIfNeeded(result) { result.error(call.method, it, null) }
                } ?: resultIfNeeded(result) { result.success(true) }
            }
        } else result.success(false)
    }

    private fun handleGetPaywalls(@NonNull call: MethodCall, @NonNull result: Result) {
        Adapty.getPaywalls { paywalls, products, _, error: String? ->
            try {
                error?.let {
                    resultIfNeeded(result) { result.error(call.method, it, null) }
                } ?: run {
                    cachePaywalls(paywalls)
                    cacheProducts(products)

                    val getPaywallsResultJson = Gson().toJson(GetPaywallsResult(paywallsIds(this.paywalls), products(products)))

                    // stream
                    channel.invokeMethod(MethodName.GET_PAYWALLS_RESULT.value, getPaywallsResultJson)

                    // result
                    resultIfNeeded(result) { result.success(getPaywallsResultJson) }
                }
            } catch (fe: FlutterException) {
                resultIfNeeded(result) { result.error(call.method, fe.message, fe.localizedMessage) }
            }
        }
    }

    private fun handleMakePurchase(@NonNull call: MethodCall, @NonNull result: Result) {
        val productId: String = call.argument<String>(PRODUCT_ID) ?: ""
        safeLet(activity, products[productId]) { activity, product ->
            Adapty.makePurchase(activity, product) { purchase, _, error ->
                error?.let {
                    resultIfNeeded(result) { result.error(call.method, it, null) }
                } ?: run {
                    resultIfNeeded(result) { result.success(Gson().toJson(MakePurchaseResult(purchase?.purchaseToken, product.skuDetails?.type))) }
                }
            }
        } ?: resultIfNeeded(result) { result.error(call.method, "No product id passed", null) }
    }

    private fun handleValidatePurchase(@NonNull call: MethodCall, @NonNull result: Result) {
        val purchaseType: String = call.argument<String>(PURCHASE_TYPE) ?: ""
        val productId: String = call.argument<String>(PRODUCT_ID) ?: ""
        val purchaseToken: String = call.argument<String>(PURCHASE_TOKEN) ?: ""

        if (purchaseType.isNotBlank() && productId.isNotBlank() && purchaseToken.isNotBlank()) {
            Adapty.validatePurchase(purchaseType, productId, purchaseToken) { _, error ->
                error?.let {
                    resultIfNeeded(result) { result.error(call.method, it, null) }
                } ?: resultIfNeeded(result) { result.success(true) }
            }
        } else {
            resultIfNeeded(result) { result.success(false) }
        }
    }

    private fun handleRestorePurchases(@NonNull call: MethodCall, @NonNull result: Result) {
        Adapty.restorePurchases { _, error ->
            error?.let {
                resultIfNeeded(result) { result.error(call.method, it, null) }
            } ?: resultIfNeeded(result) { result.success(true) }
        }
    }

    // TODO: not implemented
    private fun handleGetPurchaserInfo(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.getPurchaserInfo { _, _, error ->
            error?.let {
                resultIfNeeded(result) { result.error(call.method, it, null) }
            } ?: resultIfNeeded(result) {
                result.success(true)
            }
        }
    }

    private fun handleGetActivePurchases(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.getPurchaserInfo { purchaserInfo, _, error ->
            error?.let {
                resultIfNeeded(result) { result.error(call.method, it, null) }
            } ?: run {
                val nonSubscriptionsIds = ArrayList<String>()
                purchaserInfo?.nonSubscriptions?.values?.forEach { nonSubscriptions ->
                    nonSubscriptions.forEach { info ->
                        info.vendorProductId?.let { id -> nonSubscriptionsIds.add(id) }
                    }
                }

                val paidAccessLevel: String = call.argument<String>(PAID_ACCESS_LEVEL) ?: ""
                val subscription = purchaserInfo?.paidAccessLevels?.get(paidAccessLevel)
                val getActivePurchasesResult = Gson().toJson(
                        GetActivePurchasesResult(
                                subscription?.isActive ?: false,
                                subscription?.vendorProductId,
                                nonSubscriptionsIds
                        )
                )

                // stream
                channel.invokeMethod(MethodName.GET_ACTIVE_PURCHASES_RESULT.value, getActivePurchasesResult)

                // result
                resultIfNeeded(result) { result.success(getActivePurchasesResult) }
            }
        }
    }

    private fun handleUpdateAttribution(@NotNull call: MethodCall, @NotNull result: Result) {
        val attribution = call.argument<Map<String, String>>(ATTRIBUTION)
        val userId = call.argument<String>(USER_ID)
        val type = when (SourceType.fromValue(call.argument<String>(SOURCE))) {
            SourceType.ADJUST -> AttributionType.ADJUST
            SourceType.APPSFLYER -> AttributionType.APPSFLYER
            SourceType.BRANCH -> AttributionType.BRANCH
            else -> null
        }

        safeLet(attribution, type) { attr, source ->
            userId?.let { id ->
                Adapty.updateAttribution(attr, source, id)
            } ?: Adapty.updateAttribution(attr, source)

            resultIfNeeded(result) { result.success(true) }
        } ?: resultIfNeeded(result) {
            result.success(false)
        }
    }

    private fun handleGetPromo(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.getPromo { promo, error ->
            error?.let {
                resultIfNeeded(result) { result.error(call.method, it, null) }
            } ?: run {
                adaptyPromo(promo)?.let { adaptyPromo ->
                    resultIfNeeded(result) {
                        result.success(Gson().toJson(adaptyPromo))
                    }
                } ?: resultIfNeeded(result) { result.error(call.method, "Promo model error", null) }
            }
        }
    }

    private fun handleNewPushToken(@NotNull call: MethodCall, @NotNull result: Result) {
        val pushToken = call.argument<String>(PUSH_TOKEN) ?: ""
        if (pushToken.isNotBlank()) {
            Adapty.refreshPushToken(pushToken)
            resultIfNeeded(result) { result.success(true) }
        } else {
            resultIfNeeded(result) { result.success(false) }
        }
    }

    private fun handlePushReceived(@NotNull call: MethodCall, @NotNull result: Result) {
        val pushMessage = call.argument<Map<String, String>>(PUSH_MESSAGE) ?: emptyMap()
        resultIfNeeded(result) {
            result.success(pushHandler?.handleNotification(pushMessage) ?: false)
        }
    }

    private fun handleLogout(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.logout { error ->
            error?.let {
                resultIfNeeded(result) { result.error(call.method, it, null) }
            } ?: run {
                resultIfNeeded(result) { result.success(true) }
            }
        }
    }

    private fun listenPurchaserInfoUpdates() = Adapty.setOnPurchaserInfoUpdatedListener(object : OnPurchaserInfoUpdatedListener {
        override fun didReceiveUpdatedPurchaserInfo(purchaserInfo: PurchaserInfoModel) {

            val nonSubscriptionsIds = HashSet<String>()
            purchaserInfo.nonSubscriptions?.values?.forEach { nonSubscriptions ->
                nonSubscriptions.forEach { info ->
                    info.vendorProductId?.let { id -> nonSubscriptionsIds.add(id) }
                }
            }

            val activePaidAccessLevels = HashSet<String>()
            val activeSubscriptionsIds = HashSet<String>()
            purchaserInfo.paidAccessLevels?.forEach { (id, paidAccessLevel) ->
                if (paidAccessLevel.isActive == true) {
                    activePaidAccessLevels.add(id)
                    paidAccessLevel.vendorProductId?.let { productId ->
                        activeSubscriptionsIds.add(productId)
                    }
                }
            }

            channel.invokeMethod(MethodName.PURCHASER_INFO_UPDATE.value, Gson().toJson(
                    UpdatedPurchaserInfo(
                            nonSubscriptionsIds.toList(),
                            activePaidAccessLevels.toList(),
                            activeSubscriptionsIds.toList()
                    )
            ))
        }
    })

    private fun listenPromoUpdates() = Adapty.setOnPromoReceivedListener(object : OnPromoReceivedListener {
        override fun onPromoReceived(promo: Promo) {
            adaptyPromo(promo)?.let { adaptyPromo ->
                channel.invokeMethod(MethodName.PROMO_RECEIVED.value, Gson().toJson(adaptyPromo))
            }
        }
    })

    private fun cachePaywalls(paywalls: ArrayList<DataContainer>) = this.paywalls.run {
        clear()
        addAll(paywalls)
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

    private fun adaptyPromo(promo: Promo?) = safeLet(promo?.variationId, promo?.promoType, promo?.paywall?.variationId) { id, promoType, paywallId ->
        AdaptyPromo(id, promoType, promo?.expiresAt?.toTimestamp(PROMO_DATE_FORMAT, locale = Locale.ENGLISH)
                ?: -1, paywallId, promo?.paywall?.developerId
                ?: "", products(promo?.paywall?.products
                ?: ArrayList()))
    }

    private inline fun resultIfNeeded(@NotNull result: Result, inline: () -> Unit) {
        if (results.contains(result.hashCode())) {
            results.remove(result.hashCode())
            inline.invoke()
        }
    }
}
