@file:OptIn(InternalAdaptyApi::class)

package com.adapty.flutter

import android.app.Activity
import com.adapty.Adapty
import com.adapty.errors.AdaptyError
import com.adapty.errors.AdaptyErrorCode
import com.adapty.internal.crossplatform.CrossplatformHelper
import com.adapty.internal.utils.DEFAULT_PAYWALL_TIMEOUT_MILLIS
import com.adapty.internal.utils.InternalAdaptyApi
import com.adapty.listeners.OnProfileUpdatedListener
import com.adapty.models.*
import com.adapty.utils.AdaptyResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class AdaptyCallHandler(private val helper: CrossplatformHelper) {

    var activity: Activity? = null

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            IDENTIFY -> handleIdentify(call, result)
            SET_LOG_LEVEL -> handleSetLogLevel(call, result)
            LOG_SHOW_PAYWALL -> handleLogShowPaywall(call, result)
            LOG_SHOW_ONBOARDING -> handleLogShowOnboarding(call, result)
            GET_PAYWALL -> handleGetPaywall(call, result)
            GET_PAYWALL_PRODUCTS -> handleGetPaywallProducts(call, result)
            SET_FALLBACK_PAYWALLS -> handleSetFallbackPaywalls(call, result)
            MAKE_PURCHASE -> handleMakePurchase(call, result)
            RESTORE_PURCHASES -> handleRestorePurchases(result)
            GET_PROFILE -> handleGetProfile(result)
            UPDATE_ATTRIBUTION -> handleUpdateAttribution(call, result)
            UPDATE_PROFILE -> handleUpdateProfile(call, result)
            SET_VARIATION_ID -> handleSetVariationId(call, result)
            LOGOUT -> handleLogout(result)
            else -> result.notImplemented()
        }
    }

    fun handleProfileUpdates(channel: MethodChannel) =
        Adapty.setOnProfileUpdatedListener(object : OnProfileUpdatedListener {
            override fun onProfileReceived(profile: AdaptyProfile) {
                channel.invokeMethod(
                    DID_UPDATE_PROFILE,
                    helper.toJson(profile)
                )
            }
        })

    private fun handleIdentify(call: MethodCall, result: MethodChannel.Result) {
        val customerUserId = getArgument<String>(call, CUSTOMER_USER_ID) ?: kotlin.run {
            callParameterError(call, result, CUSTOMER_USER_ID)
            return
        }

        Adapty.identify(customerUserId) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleSetLogLevel(call: MethodCall, result: MethodChannel.Result) {
        val logLevel = try { helper.toLogLevel(call.argument<String>(VALUE)) } catch (e: Exception) { null }

        if (logLevel != null) {
            Adapty.logLevel = logLevel
            result.success(null)
        } else {
            callParameterError(call, result, VALUE)
        }
    }

    private fun handleLogShowPaywall(call: MethodCall, result: MethodChannel.Result) {
        val paywall = parseJsonArgument<AdaptyPaywall>(call, PAYWALL) ?: kotlin.run {
            callParameterError(call, result, PAYWALL)
            return
        }

        Adapty.logShowPaywall(paywall) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleLogShowOnboarding(call: MethodCall, result: MethodChannel.Result) {
        val onboardingParams = parseJsonArgument<HashMap<*, *>>(call, ONBOARDING_PARAMS) ?: kotlin.run {
            callParameterError(call, result, ONBOARDING_PARAMS)
            return
        }

        val screenOrder = (onboardingParams["onboarding_screen_order"] as? Number)?.toInt() ?: kotlin.run {
            callParameterError(call, result, ONBOARDING_PARAMS)
            return
        }

        Adapty.logShowOnboarding(
            onboardingParams["onboarding_name"] as? String,
            onboardingParams["onboarding_screen_name"] as? String,
            screenOrder,
        ) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleGetPaywall(call: MethodCall, result: MethodChannel.Result) {
        val placementId = getArgument<String>(call, PLACEMENT_ID) ?: kotlin.run {
            callParameterError(call, result, PLACEMENT_ID)
            return
        }

        val locale = getArgument<String>(call, LOCALE)
        val fetchPolicy = parseJsonArgument(call, FETCH_POLICY) ?: AdaptyPaywall.FetchPolicy.Default
        val loadTimeoutMillis = getArgument<Number>(call, LOAD_TIMEOUT)?.toDouble()?.times(PAYWALL_TIMEOUT_MULTIPLIER)?.toInt() ?: DEFAULT_PAYWALL_TIMEOUT_MILLIS

        Adapty.getPaywall(placementId, locale, fetchPolicy, loadTimeoutMillis) { adaptyResult ->
            handleAdaptyResult(result, adaptyResult)
        }
    }

    private fun handleGetPaywallProducts(call: MethodCall, result: MethodChannel.Result) {
        val paywall = parseJsonArgument<AdaptyPaywall>(call, PAYWALL) ?: kotlin.run {
            callParameterError(call, result, PAYWALL)
            return
        }

        Adapty.getPaywallProducts(paywall) { adaptyResult ->
            handleAdaptyResult(result, adaptyResult)
        }
    }

    private fun handleMakePurchase(call: MethodCall, result: MethodChannel.Result) {
        val product = parseJsonArgument<AdaptyPaywallProduct>(call, PRODUCT) ?: kotlin.run {
            callParameterError(call, result, PRODUCT)
            return
        }

        val subscriptionUpdateParams =
            parseJsonArgument<AdaptySubscriptionUpdateParameters>(call, PARAMS)

        val isOfferPersonalized = getArgument(call, IS_OFFER_PERSONALIZED) ?: false

        activity?.let { activity ->
            Adapty.makePurchase(
                activity,
                product,
                subscriptionUpdateParams,
                isOfferPersonalized,
            ) { adaptyResult ->
                handleAdaptyResult(result, adaptyResult)
            }
        }
    }

    private fun handleRestorePurchases(result: MethodChannel.Result) {
        Adapty.restorePurchases { adaptyResult ->
            handleAdaptyResult(result, adaptyResult)
        }
    }

    private fun handleGetProfile(result: MethodChannel.Result) {
        Adapty.getProfile { adaptyResult ->
            handleAdaptyResult(result, adaptyResult)
        }
    }

    private fun handleUpdateAttribution(call: MethodCall, result: MethodChannel.Result) {
        val attribution = (try {
            call.argument<Map<String, String>>(ATTRIBUTION)
        } catch (e: Exception) { null }) ?: kotlin.run {
            callParameterError(call, result, ATTRIBUTION)
            return
        }

        val source = helper.toAttributionSourceType(getArgument<String>(call, SOURCE)) ?: kotlin.run {
            callParameterError(call, result, ATTRIBUTION)
            return
        }

        val userId = getArgument<String>(call, NETWORK_USER_ID)

        Adapty.updateAttribution(attribution, source, userId) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleUpdateProfile(call: MethodCall, result: MethodChannel.Result) {
        val profileParams = parseJsonArgument<AdaptyProfileParameters>(call, PARAMS) ?: kotlin.run {
            callParameterError(call, result, PARAMS)
            return
        }

        Adapty.updateProfile(profileParams) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleSetVariationId(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val transactionId = getArgument<String>(call, TRANSACTION_ID)?.takeIf(String::isNotBlank) ?: kotlin.run {
            callParameterError(call, result, TRANSACTION_ID)
            return
        }

        val variationId = getArgument<String>(call, VARIATION_ID)?.takeIf(String::isNotBlank) ?: kotlin.run {
            callParameterError(call, result, VARIATION_ID)
            return
        }

        Adapty.setVariationId(transactionId, variationId) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleSetFallbackPaywalls(call: MethodCall, result: MethodChannel.Result) {
        val fallbackPaywalls = getArgument<String>(call, PAYWALLS) ?: kotlin.run {
            callParameterError(call, result, PAYWALLS)
            return
        }

        Adapty.setFallbackPaywalls(fallbackPaywalls) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleLogout(result: MethodChannel.Result) {
        Adapty.logout { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleAdaptyResult(result: MethodChannel.Result, adaptyResult: AdaptyResult<*>) {
        when (adaptyResult) {
            is AdaptyResult.Success -> result.success(adaptyResult.value?.let(helper::toJson))
            is AdaptyResult.Error -> {
                handleAdaptyError(result, adaptyResult.error)
            }
        }
    }

    private inline fun <reified T: Any> parseJsonArgument(call: MethodCall, paramKey: String): T? {
        return try {
            call.argument<String>(paramKey)?.takeIf(String::isNotEmpty)?.let { json ->
                helper.fromJson(json, T::class.java)
            }
        } catch (e: Exception) { null }
    }

    private fun <T : Any> getArgument(call: MethodCall, paramKey: String): T? {
        return try {
            call.argument<T>(paramKey)
        } catch (e: Exception) {
            null
        }
    }

    private fun emptyResultOrError(result: MethodChannel.Result, error: AdaptyError?) {
        if (error == null) {
            result.success(null)
        } else {
            handleAdaptyError(result, error)
        }
    }

    private fun handleAdaptyError(result: MethodChannel.Result, error: AdaptyError) {
        result.error(
            ADAPTY_ERROR_CODE,
            error.message,
            helper.toJson(error)
        )
    }

    private fun callParameterError(
        call: MethodCall,
        result: MethodChannel.Result,
        paramKey: String,
        originalError: Throwable? = null
    ) {
        val message = "Error while parsing parameter: $paramKey"
        val detail =
            "Method: ${call.method}, Parameter: $paramKey, OriginalError: ${originalError?.localizedMessage ?: originalError?.message}"
        result.error(
            ADAPTY_ERROR_CODE,
            message,
            mapOf(
                ADAPTY_ERROR_CODE_KEY to AdaptyErrorCode.DECODING_FAILED,
                ADAPTY_ERROR_MESSAGE_KEY to message,
                ADAPTY_ERROR_DETAIL_KEY to detail,
            )
        )
    }

    private companion object {
        //Method ids
        const val SET_LOG_LEVEL = "set_log_level"
        const val GET_PROFILE = "get_profile"
        const val UPDATE_PROFILE = "update_profile"
        const val IDENTIFY = "identify"
        const val GET_PAYWALL = "get_paywall"
        const val GET_PAYWALL_PRODUCTS = "get_paywall_products"
        const val MAKE_PURCHASE = "make_purchase"
        const val RESTORE_PURCHASES = "restore_purchases"
        const val UPDATE_ATTRIBUTION = "update_attribution"
        const val LOG_SHOW_PAYWALL = "log_show_paywall"
        const val LOG_SHOW_ONBOARDING = "log_show_onboarding"
        const val SET_VARIATION_ID = "set_transaction_variation_id"
        const val SET_FALLBACK_PAYWALLS = "set_fallback_paywalls"
        const val LOGOUT = "logout"
        const val DID_UPDATE_PROFILE = "did_update_profile"

        // Arguments
        const val CUSTOMER_USER_ID = "customer_user_id"
        const val ID = "id"
        const val PAYWALL = "paywall"
        const val PRODUCT = "product"
        const val LOCALE = "locale"
        const val PLACEMENT_ID = "placement_id"
        const val FETCH_POLICY = "fetch_policy"
        const val LOAD_TIMEOUT = "load_timeout"
        const val VARIATION_ID = "variation_id"
        const val TRANSACTION_ID = "transaction_id"
        const val ATTRIBUTION = "attribution"
        const val PARAMS = "params"
        const val ONBOARDING_PARAMS = "onboarding_params"
        const val PAYWALLS = "paywalls"
        const val NETWORK_USER_ID = "network_user_id"
        const val SOURCE = "source"
        const val VALUE = "value"
        const val IS_OFFER_PERSONALIZED = "is_offer_personalized"

        // Error handling
        const val ADAPTY_ERROR_CODE = "adapty_flutter_android"
        const val ADAPTY_ERROR_MESSAGE_KEY = "message"
        const val ADAPTY_ERROR_DETAIL_KEY = "detail"
        const val ADAPTY_ERROR_CODE_KEY = "adapty_code"

        const val PAYWALL_TIMEOUT_MULTIPLIER = 1000
    }
}