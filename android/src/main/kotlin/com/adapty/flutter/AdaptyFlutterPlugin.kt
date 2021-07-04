package com.adapty.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.annotation.NonNull
import com.adapty.Adapty
import com.adapty.errors.AdaptyError
import com.adapty.errors.AdaptyErrorCode
import com.adapty.flutter.constants.*
import com.adapty.flutter.extensions.safeLet
import com.adapty.flutter.extensions.toProfileParamBuilder
import com.adapty.flutter.extensions.toSubscriptionUpdateParamModel
import com.adapty.flutter.models.*
import com.adapty.flutter.push.AdaptyFlutterPushHandler
import com.adapty.listeners.OnPromoReceivedListener
import com.adapty.listeners.OnPurchaserInfoUpdatedListener
import com.adapty.listeners.VisualPaywallListener
import com.adapty.models.*
import com.adapty.utils.AdaptyLogLevel
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.jetbrains.annotations.NotNull
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

        fun handleIntent(intent: Intent) = Adapty.handlePromoIntent(intent) { promo, error ->
            // do nothing
        }
    }

    private lateinit var channel: MethodChannel

    private var activity: Activity? = null
    private var results = HashSet<Int>()

    private var paywalls = ArrayList<PaywallModel>()
    private var products = HashMap<String, ProductModel>()

    private var pushHandler: AdaptyFlutterPushHandler? = null

    private val gson: Gson by lazy { Gson() }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(
            flutterPluginBinding.applicationContext,
            flutterPluginBinding.binaryMessenger
        )
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (!results.contains(result.hashCode())) {
            results.add(result.hashCode())
            when (MethodName.fromValue(call.method)) {
                MethodName.IDENTIFY -> handleIdentify(call, result)
                MethodName.SET_LOG_LEVEL -> handleSetLogLevel(call, result)
                MethodName.LOG_SHOW_PAYWALL -> handleLogShowPaywall(call)
                MethodName.SHOW_VISUAL_PAYWALL -> handleShowPaywall(call)
                MethodName.CLOSE_VISUAL_PAYWALL -> handleClosePaywall(call)
                MethodName.GET_PAYWALLS -> handleGetPaywalls(call, result)
                MethodName.SET_FALLBACK_PAYWALLS -> handleSetFallbackPaywalls(call, result)
                MethodName.MAKE_PURCHASE -> handleMakePurchase(call, result)
                MethodName.RESTORE_PURCHASES -> handleRestorePurchases(call, result)
                MethodName.GET_PURCHASER_INFO -> handleGetPurchaserInfo(call, result)
                MethodName.UPDATE_ATTRIBUTION -> handleUpdateAttribution(call, result)
                MethodName.UPDATE_PROFILE -> handleUpdateProfile(call, result)
                MethodName.GET_PROMO -> handleGetPromo(call, result)
                MethodName.NEW_PUSH_TOKEN -> handleNewPushToken(call, result)
                MethodName.PUSH_RECEIVED -> handlePushReceived(call, result)
                MethodName.SET_TRANSACTION_VARIATION_ID -> handleSetTransactionVariationId(
                    call,
                    result
                )
                MethodName.SET_EXTERNAL_ANALYTICS_ENABLED -> handleSetExternalAnalyticsEnabled(
                    call,
                    result
                )
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
        activateOnLaunch(context)
    }

    private fun onNewActivityPluginBinding(binding: ActivityPluginBinding?) = if (binding == null) {
        activity = null
    } else {
        activity = binding.activity
    }

    private fun activateOnLaunch(context: Context) {
        val apiKey = context.packageManager
            .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            .metaData
            ?.getString("AdaptyPublicSdkKey")
            .orEmpty()

        Adapty.activate(context, apiKey)

        listenPurchaserInfoUpdates()
        listenPromoUpdates()
        listenVisualPaywallEvents()
    }

    private fun handleIdentify(@NonNull call: MethodCall, @NonNull result: Result) {
        call.argument<String>(CUSTOMER_USER_ID)?.takeIf(String::isNotEmpty)?.let { customerUserId ->
            Adapty.identify(customerUserId) { error ->
                error?.let { adaptyError ->
                    resultIfNeeded(result) { errorFromAdaptyError(call, result, adaptyError) }
                } ?: resultIfNeeded(result) { result.success(true) }
            }
        } ?: resultIfNeeded(result) {
            errorEmptyParam(call, result, "Error while parsing parameter: $CUSTOMER_USER_ID")
        }
    }

    private fun handleSetLogLevel(@NonNull call: MethodCall, @NonNull result: Result) {
        resultIfNeeded(result) {
            call.argument<Int>(VALUE)?.let { logLevelIndex ->
                Adapty.setLogLevel(
                    when (logLevelIndex) {
                        2 -> AdaptyLogLevel.VERBOSE
                        1 -> AdaptyLogLevel.ERROR
                        else -> AdaptyLogLevel.NONE
                    }
                )
                result.success(true)
            } ?: errorEmptyParam(call, result, "Error while parsing parameter: $VALUE")
        }
    }

    private fun handleLogShowPaywall(@NonNull call: MethodCall) {
        paywalls.firstOrNull { it.variationId == call.argument<String>(VARIATION_ID) }
            ?.let(Adapty::logShowPaywall)
    }

    private fun handleShowPaywall(@NonNull call: MethodCall) {
        val paywall = paywalls.firstOrNull { it.variationId == call.argument<String>(VARIATION_ID) }
        safeLet(activity, paywall) { activity, paywall ->
            Adapty.showPaywall(activity, paywall)
        }
    }

    private fun handleClosePaywall(@NonNull call: MethodCall) {
        Adapty.closePaywall()
    }

    private fun handleGetPaywalls(@NonNull call: MethodCall, @NonNull result: Result) {
        Adapty.getPaywalls(
            call.argument<Boolean>(FORCE_UPDATE) ?: false
        ) { paywalls, products, error ->
            try {
                error?.let { adaptyError ->
                    resultIfNeeded(result) { errorFromAdaptyError(call, result, adaptyError) }
                } ?: run {
                    val paywalls = paywalls ?: listOf()
                    val products = products ?: listOf()
                    cachePaywalls(paywalls)
                    cacheProducts(products)

                    val getPaywallsResultJson = gson.toJson(
                        GetPaywallsResult(
                            paywalls.map(PaywallFlutterModel::from),
                            products.map(ProductFlutterModel.Companion::from)
                        )
                    )

                    // stream
                    channel.invokeMethod(
                        MethodName.GET_PAYWALLS_RESULT.value,
                        getPaywallsResultJson
                    )

                    // result
                    resultIfNeeded(result) { result.success(getPaywallsResultJson) }
                }
            } catch (fe: FlutterException) {
                resultIfNeeded(result) { result.error(call.method, fe.message, null) }
            }
        }
    }

    private fun handleMakePurchase(@NonNull call: MethodCall, @NonNull result: Result) {
        val productId: String = call.argument<String>(PRODUCT_ID) ?: ""
        val variationId: String? = call.argument<String>(VARIATION_ID)
        val product = variationId?.let { variationId ->
            paywalls.firstOrNull { it.variationId == variationId }?.products?.firstOrNull { it.vendorProductId == productId }
        } ?: products[productId]
        val subscriptionUpdateParams = call.argument<Map<String, String>>(PARAMS)
            ?.toSubscriptionUpdateParamModel()
        safeLet(activity, product) { activity, product ->
            Adapty.makePurchase(
                activity,
                product,
                subscriptionUpdateParams,
            ) { purchaserInfo, purchaseToken, googleValidationResult, product, error ->
                resultIfNeeded(result) {
                    error?.let { adaptyError ->
                        errorFromAdaptyError(call, result, adaptyError)
                    } ?: result.success(
                        gson.toJson(
                            MakePurchaseResult(
                                purchaserInfo,
                                purchaseToken,
                                googleValidationResult,
                                ProductFlutterModel.from(product)
                            )
                        )
                    )
                }
            }
        } ?: resultIfNeeded(result) { errorEmptyParam(call, result, "No product id passed") }
    }

    private fun handleRestorePurchases(@NonNull call: MethodCall, @NonNull result: Result) {
        Adapty.restorePurchases { purchaserInfo, googleValidationResultList, error ->
            resultIfNeeded(result) {
                error?.let { adaptyError ->
                    errorFromAdaptyError(call, result, adaptyError)
                } ?: result.success(
                    gson.toJson(
                        RestorePurchasesResult(purchaserInfo, googleValidationResultList)
                    )
                )
            }
        }
    }

    private fun handleGetPurchaserInfo(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.getPurchaserInfo(
            call.argument<Boolean>(FORCE_UPDATE) ?: false
        ) { purchaserInfo, error ->
            resultIfNeeded(result) {
                error?.let { adaptyError ->
                    errorFromAdaptyError(call, result, adaptyError)
                } ?: result.success(gson.toJson(purchaserInfo))
                return@getPurchaserInfo
            }
            purchaserInfo?.let {
                channel.invokeMethod(
                    MethodName.PURCHASER_INFO_UPDATE.value,
                    gson.toJson(it)
                )
            }
        }
    }

    private fun handleUpdateAttribution(@NotNull call: MethodCall, @NotNull result: Result) {
        val attribution = call.argument<Map<String, String>>(ATTRIBUTION)
        val userId = call.argument<String>(NETWORK_USER_ID)
        val type = when (SourceType.fromValue(call.argument<String>(SOURCE))) {
            SourceType.ADJUST -> AttributionType.ADJUST
            SourceType.APPSFLYER -> AttributionType.APPSFLYER
            SourceType.BRANCH -> AttributionType.BRANCH
            SourceType.CUSTOM -> AttributionType.CUSTOM
            else -> null
        }

        safeLet(attribution, type) { attr, source ->
            userId?.let { id ->
                Adapty.updateAttribution(attr, source, id) { error ->
                    resultIfNeeded(result) { emptyResultOrError(call, result, error) }
                }
            } ?: Adapty.updateAttribution(attr, source) { error ->
                resultIfNeeded(result) { emptyResultOrError(call, result, error) }
            }
        } ?: resultIfNeeded(result) {
            errorEmptyParam(call, result, "Attribution or source is empty")
        }
    }

    private fun handleUpdateProfile(@NotNull call: MethodCall, @NotNull result: Result) {
        val profileParams = call.argument<Map<String, Any>>(PARAMS)
        Adapty.updateProfile(profileParams.toProfileParamBuilder()) { error ->
            resultIfNeeded(result) {
                emptyResultOrError(call, result, error)
            }
        }

    }

    private fun handleGetPromo(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.getPromo { promo, error ->
            resultIfNeeded(result) {
                error?.let { adaptyError ->
                    errorFromAdaptyError(call, result, adaptyError)
                } ?: result.success(if (promo == null) null else gson.toJson(PromoFlutterModel.from(promo)))
            }
        }
    }

    private fun handleNewPushToken(@NotNull call: MethodCall, @NotNull result: Result) {
        val pushToken = call.argument<String>(PUSH_TOKEN) ?: ""
        if (pushToken.isNotBlank()) {
            Adapty.refreshPushToken(pushToken)
            resultIfNeeded(result) { result.success(true) }
        } else {
            resultIfNeeded(result) { errorEmptyParam(call, result, "Push token is empty") }
        }
    }

    private fun handlePushReceived(@NotNull call: MethodCall, @NotNull result: Result) {
        val pushMessage = call.argument<Map<String, String>>(PUSH_MESSAGE) ?: emptyMap()
        resultIfNeeded(result) {
            pushHandler?.handleNotification(pushMessage)?.let {
                result.success(it)
            } ?: "pushHandler is null".let { message ->
                result.error(
                    call.method,
                    message,
                    gson.toJson(AdaptyFlutterError.from(AdaptyErrorCode.UNKNOWN, message))
                )
            }
        }
    }

    private fun handleSetTransactionVariationId(
        @NonNull call: MethodCall,
        @NonNull result: Result
    ) {
        val transactionId = call.argument<String>(TRANSACTION_ID)
        val variationId = call.argument<String>(VARIATION_ID)
        when {
            transactionId.isNullOrBlank() -> {
                resultIfNeeded(result) { errorEmptyParam(call, result, "No transaction id passed") }
            }
            variationId.isNullOrBlank() -> {
                resultIfNeeded(result) { errorEmptyParam(call, result, "No variation id passed") }
            }
            else -> {
                Adapty.setTransactionVariationId(transactionId, variationId) { error ->
                    resultIfNeeded(result) { emptyResultOrError(call, result, error) }
                }
            }
        }
    }

    private fun handleSetExternalAnalyticsEnabled(
        @NonNull call: MethodCall,
        @NonNull result: Result
    ) {
        call.argument<Boolean>(VALUE)?.let { enabled ->
            Adapty.setExternalAnalyticsEnabled(enabled) { error ->
                resultIfNeeded(result) { emptyResultOrError(call, result, error) }
            }
        } ?: resultIfNeeded(result) {
            errorEmptyParam(
                call,
                result,
                "No value passed. Please specify boolean parameter explicitly"
            )
        }
    }

    private fun handleSetFallbackPaywalls(@NotNull call: MethodCall, @NotNull result: Result) {
        call.argument<String>(PAYWALLS)?.let { paywalls ->
            Adapty.setFallbackPaywalls(paywalls) { error ->
                resultIfNeeded(result) {
                    emptyResultOrError(call, result, error)
                }
            }
        } ?: resultIfNeeded(result) {
            errorEmptyParam(call, result, "No paywalls passed")
        }
    }

    private fun handleLogout(@NotNull call: MethodCall, @NotNull result: Result) {
        Adapty.logout { error ->
            resultIfNeeded(result) {
                emptyResultOrError(call, result, error)
            }
        }
    }

    private fun listenPurchaserInfoUpdates() =
        Adapty.setOnPurchaserInfoUpdatedListener(object : OnPurchaserInfoUpdatedListener {
            override fun onPurchaserInfoReceived(purchaserInfo: PurchaserInfoModel) {
                channel.invokeMethod(
                    MethodName.PURCHASER_INFO_UPDATE.value,
                    gson.toJson(purchaserInfo)
                )
            }
        })

    private fun listenPromoUpdates() =
        Adapty.setOnPromoReceivedListener(object : OnPromoReceivedListener {
            override fun onPromoReceived(promo: PromoModel) {
                channel.invokeMethod(
                    MethodName.PROMO_RECEIVED.value,
                    gson.toJson(PromoFlutterModel.from(promo))
                )
            }
        })

    private fun listenVisualPaywallEvents() =
        Adapty.setVisualPaywallListener(object : VisualPaywallListener {
            override fun onClosed() {
                channel.invokeMethod(MethodName.VISUAL_PAYWALL_CLOSED_RESULT.value, null)
            }

            override fun onPurchaseFailure(product: ProductModel, error: AdaptyError) {
                channel.invokeMethod(
                    MethodName.VISUAL_PAYWALL_PURCHASE_FAILURE_RESULT.value, gson.toJson(
                        VisualPaywallPurchaseFailureResult(
                            ProductFlutterModel.from(product), AdaptyFlutterError.from(error)
                        )
                    )
                )
            }

            override fun onPurchased(
                purchaserInfo: PurchaserInfoModel?,
                purchaseToken: String?,
                googleValidationResult: GoogleValidationResult?,
                product: ProductModel
            ) {
                channel.invokeMethod(
                    MethodName.VISUAL_PAYWALL_PURCHASE_SUCCESS_RESULT.value, gson.toJson(
                        VisualPaywallPurchaseSuccessResult(
                            purchaserInfo,
                            purchaseToken,
                            googleValidationResult,
                            ProductFlutterModel.from(product)
                        )
                    )
                )
            }

            override fun onRestorePurchases(
                purchaserInfo: PurchaserInfoModel?,
                googleValidationResultList: List<GoogleValidationResult>?,
                error: AdaptyError?
            ) {
                channel.invokeMethod(
                    MethodName.VISUAL_PAYWALL_RESTORE_PURCHASES_RESULT.value, gson.toJson(
                        VisualPaywallRestorePurchasesResult(
                            purchaserInfo,
                            googleValidationResultList,
                            error?.let(AdaptyFlutterError::from)
                        )
                    )
                )
            }
        })

    private fun cachePaywalls(paywalls: List<PaywallModel>) = this.paywalls.run {
        clear()
        addAll(paywalls)
    }

    private fun cacheProducts(products: List<ProductModel>) = this.products.run {
        clear()
        products.forEach { product ->
            put(product.vendorProductId, product)
        }
    }

    private fun errorEmptyParam(call: MethodCall, result: Result, message: String) =
        result.error(
            call.method,
            message,
            gson.toJson(AdaptyFlutterError.from(AdaptyErrorCode.MISSING_PARAMETER, message))
        )

    private fun errorFromAdaptyError(call: MethodCall, result: Result, adaptyError: AdaptyError) =
        result.error(
            call.method,
            adaptyError.message,
            gson.toJson(AdaptyFlutterError.from(adaptyError))
        )

    private fun emptyResultOrError(call: MethodCall, result: Result, error: AdaptyError?) =
        error?.let { adaptyError ->
            errorFromAdaptyError(call, result, adaptyError)
        } ?: result.success(true)

    private inline fun resultIfNeeded(@NotNull result: Result, inline: () -> Unit) {
        if (results.contains(result.hashCode())) {
            results.remove(result.hashCode())
            inline.invoke()
        }
    }
}
