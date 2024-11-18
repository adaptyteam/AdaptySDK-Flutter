@file:OptIn(InternalAdaptyApi::class)

package com.adapty.flutter

import android.app.Activity
import android.content.Context
import com.adapty.Adapty
import com.adapty.errors.AdaptyError
import com.adapty.errors.AdaptyErrorCode
import com.adapty.internal.crossplatform.ActivateArgs
import com.adapty.internal.crossplatform.CrossplatformHelper
import com.adapty.internal.crossplatform.GetPaywallArgs
import com.adapty.internal.crossplatform.GetPaywallForDefaultAudienceArgs
import com.adapty.internal.crossplatform.GetPaywallProductsArgs
import com.adapty.internal.crossplatform.IdentifyArgs
import com.adapty.internal.crossplatform.LogShowOnboardingArgs
import com.adapty.internal.crossplatform.LogShowPaywallArgs
import com.adapty.internal.crossplatform.MakePurchaseArgs
import com.adapty.internal.crossplatform.PurchaseResult
import com.adapty.internal.crossplatform.SetFallbackPaywallsArgs
import com.adapty.internal.crossplatform.SetLogLevelArgs
import com.adapty.internal.crossplatform.SetVariationIdArgs
import com.adapty.internal.crossplatform.UpdateAttributionArgs
import com.adapty.internal.crossplatform.UpdateProfileArgs
import com.adapty.internal.crossplatform.asPurchaseResult
import com.adapty.internal.crossplatform.ui.ActivateUiArgs
import com.adapty.internal.crossplatform.ui.AdaptyUiBridgeError
import com.adapty.internal.crossplatform.ui.CreateViewArgs
import com.adapty.internal.crossplatform.ui.CrossplatformUiHelper
import com.adapty.internal.crossplatform.ui.DismissViewArgs
import com.adapty.internal.crossplatform.ui.PresentViewArgs
import com.adapty.internal.crossplatform.ui.ShowDialogArgs
import com.adapty.internal.utils.DEFAULT_PAYWALL_TIMEOUT
import com.adapty.internal.utils.InternalAdaptyApi
import com.adapty.internal.utils.adaptySdkVersion
import com.adapty.listeners.OnProfileUpdatedListener
import com.adapty.models.AdaptyPaywall
import com.adapty.models.AdaptyProfile
import com.adapty.models.AdaptyPurchasedInfo
import com.adapty.ui.AdaptyUI
import com.adapty.utils.AdaptyResult
import com.adapty.utils.FileLocation
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterMain.getLookupKeyForAsset

internal class AdaptyCallHandler(
    private val helper: CrossplatformHelper,
    private val uiHelper: CrossplatformUiHelper,
) {

    var activity: Activity? = null
        set(value) {
            field = value
            uiHelper.activity = value
        }
    var appContext: Context? = null

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result, channel: MethodChannel) {
        when (call.method) {
            ACTIVATE -> handleActivate(call, result, channel)
            IDENTIFY -> handleIdentify(call, result)
            SET_LOG_LEVEL -> handleSetLogLevel(call, result)
            LOG_SHOW_PAYWALL -> handleLogShowPaywall(call, result)
            LOG_SHOW_ONBOARDING -> handleLogShowOnboarding(call, result)
            GET_PAYWALL -> handleGetPaywall(call, result)
            GET_PAYWALL_FOR_DEFAULT_AUDIENCE -> handleGetPaywallForDefaultAudience(call, result)
            GET_PAYWALL_PRODUCTS -> handleGetPaywallProducts(call, result)
            SET_FALLBACK_PAYWALLS -> handleSetFallbackPaywalls(call, result)
            MAKE_PURCHASE -> handleMakePurchase(call, result)
            RESTORE_PURCHASES -> handleRestorePurchases(result)
            GET_PROFILE -> handleGetProfile(result)
            UPDATE_ATTRIBUTION -> handleUpdateAttribution(call, result)
            UPDATE_PROFILE -> handleUpdateProfile(call, result)
            SET_VARIATION_ID -> handleSetVariationId(call, result)
            LOGOUT -> handleLogout(result)
            IS_ACTIVATED -> handleIsActivated(result)
            GET_SDK_VERSION -> handleGetSdkVersion(result)
            ADAPTY_UI_ACTIVATE -> handleUiActivate(call, result)
            ADAPTY_UI_CREATE_VIEW -> handleCreateView(call, result)
            ADAPTY_UI_PRESENT_VIEW -> handlePresentView(call, result)
            ADAPTY_UI_DISMISS_VIEW -> handleDismissView(call, result)
            ADAPTY_UI_SHOW_DIALOG -> handleShowDialog(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleActivate(call: MethodCall, result: MethodChannel.Result, channel: MethodChannel) {
        val args = parseJsonArgument<ActivateArgs>(call) ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        val config = args.configuration

        val context = appContext ?: return

        config.logLevel?.let { logLevel -> Adapty.logLevel = logLevel }
        Adapty.activate(
            context,
            config.baseConfig,
        )

        handleProfileUpdates(channel)
        success(result)
    }

    private fun handleProfileUpdates(channel: MethodChannel) =
        Adapty.setOnProfileUpdatedListener(object : OnProfileUpdatedListener {
            override fun onProfileReceived(profile: AdaptyProfile) {
                channel.invokeMethod(
                    DID_LOAD_LATEST_PROFILE,
                    helper.toJson(profile)
                )
            }
        })

    private fun handleIdentify(call: MethodCall, result: MethodChannel.Result) {
        val customerUserId = parseJsonArgument<IdentifyArgs>(call)?.customerUserId ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.identify(customerUserId) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleSetLogLevel(call: MethodCall, result: MethodChannel.Result) {
        val logLevel = parseJsonArgument<SetLogLevelArgs>(call)?.value ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.logLevel = logLevel
        success(result)
    }

    private fun handleLogShowPaywall(call: MethodCall, result: MethodChannel.Result) {
        val paywall = parseJsonArgument<LogShowPaywallArgs>(call)?.paywall ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.logShowPaywall(paywall) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleLogShowOnboarding(call: MethodCall, result: MethodChannel.Result) {
        val onboardingParams = parseJsonArgument<LogShowOnboardingArgs>(call)?.params ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        val screenOrder = (onboardingParams["onboarding_screen_order"] as? Number)?.toInt() ?: kotlin.run {
            callParameterError(call, result)
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
        val args = parseJsonArgument<GetPaywallArgs>(call)?.takeIf { it.placementId != null } ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.getPaywall(
            args.placementId,
            args.locale,
            args.fetchPolicy ?: AdaptyPaywall.FetchPolicy.Default,
            args.loadTimeout ?: DEFAULT_PAYWALL_TIMEOUT,
        ) { adaptyResult ->
            adaptyResult(result, adaptyResult)
        }
    }

    private fun handleGetPaywallForDefaultAudience(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<GetPaywallForDefaultAudienceArgs>(call)?.takeIf { it.placementId != null } ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.getPaywallForDefaultAudience(
            args.placementId,
            args.locale,
            args.fetchPolicy ?: AdaptyPaywall.FetchPolicy.Default,
        ) { adaptyResult ->
            adaptyResult(result, adaptyResult)
        }
    }

    private fun handleGetPaywallProducts(call: MethodCall, result: MethodChannel.Result) {
        val paywall = parseJsonArgument<GetPaywallProductsArgs>(call)?.paywall ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.getPaywallProducts(paywall) { adaptyResult ->
            adaptyResult(result, adaptyResult)
        }
    }

    private fun handleMakePurchase(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<MakePurchaseArgs>(call)?.takeIf { it.product != null } ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        activity?.let { activity ->
            Adapty.makePurchase(
                activity,
                args.product,
                args.subscriptionUpdateParams,
                args.isOfferPersonalized,
            ) { adaptyResult ->
                purchaseResult(result, adaptyResult)
            }
        }
    }

    private fun handleRestorePurchases(result: MethodChannel.Result) {
        Adapty.restorePurchases { adaptyResult ->
            adaptyResult(result, adaptyResult)
        }
    }

    private fun handleGetProfile(result: MethodChannel.Result) {
        Adapty.getProfile { adaptyResult ->
            adaptyResult(result, adaptyResult)
        }
    }

    private fun handleUpdateAttribution(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<UpdateAttributionArgs>(call) ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.updateAttribution(args.attribution, args.source, args.networkUserId) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleUpdateProfile(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<UpdateProfileArgs>(call)?.takeIf { it.params != null } ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.updateProfile(args.params) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleSetVariationId(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val args = parseJsonArgument<SetVariationIdArgs>(call)
            ?.takeIf {
                !it.transactionId.isNullOrEmpty() && !it.variationId.isNullOrEmpty()
            }
            ?: kotlin.run {
                callParameterError(call, result)
                return
            }

        Adapty.setVariationId(args.transactionId, args.variationId) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleSetFallbackPaywalls(call: MethodCall, result: MethodChannel.Result) {
        val assetId = parseJsonArgument<SetFallbackPaywallsArgs>(call)?.assetId ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        Adapty.setFallbackPaywalls(FileLocation.fromAsset(getLookupKeyForAsset(assetId))) { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleLogout(result: MethodChannel.Result) {
        Adapty.logout { error ->
            emptyResultOrError(result, error)
        }
    }

    private fun handleIsActivated(result: MethodChannel.Result) {
        success(result, Adapty.isActivated)
    }

    private fun handleGetSdkVersion(result: MethodChannel.Result) {
        success(result, adaptySdkVersion)
    }

    fun handleUiEvents(channel: MethodChannel) {
        uiHelper.uiEventsObserver = { event ->
            channel.invokeMethod(
                event.name,
                event.data.mapValues { entry ->
                    if (entry.value is String) entry.value else helper.toJson(entry.value)
                }
            )
        }
    }

    private fun handleUiActivate(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<ActivateUiArgs>(call) ?: kotlin.run {
            callParameterError(call, result)
            return
        }
        AdaptyUI.configureMediaCache(args.configuration)
        success(result)
    }

    private fun handleCreateView(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<CreateViewArgs>(call) ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        uiHelper.handleCreateView(
            args,
            { view -> success(result, view) },
            { error -> adaptyError(result, error) },
        )
    }

    private fun handlePresentView(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<PresentViewArgs>(call) ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        uiHelper.handlePresentView(
            args.id,
            { success(result) },
            { error -> uiBridgeError(result, error) },
        )
    }

    private fun handleDismissView(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<DismissViewArgs>(call) ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        uiHelper.handleDismissView(
            args.id,
            { success(result) },
            { error -> uiBridgeError(result, error) },
        )
    }

    private fun handleShowDialog(call: MethodCall, result: MethodChannel.Result) {
        val args = parseJsonArgument<ShowDialogArgs>(call) ?: kotlin.run {
            callParameterError(call, result)
            return
        }

        uiHelper.handleShowDialog(
            args.id,
            args.configuration,
            { action -> result.success(action) },
            { error -> uiBridgeError(result, error) },
        )
    }

    private fun adaptyResult(result: MethodChannel.Result, adaptyResult: AdaptyResult<*>) {
        when (adaptyResult) {
            is AdaptyResult.Success -> success(result, adaptyResult.value)
            is AdaptyResult.Error -> adaptyError(result, adaptyResult.error)
        }
    }

    private fun purchaseResult(
        result: MethodChannel.Result,
        adaptyResult: AdaptyResult<AdaptyPurchasedInfo?>,
    ) {
        when (val purchaseResult = adaptyResult.asPurchaseResult()) {
            is PurchaseResult.Error -> adaptyError(result, purchaseResult.error)
            is PurchaseResult.Deferred -> {
                Adapty.getProfile { profileResult ->
                    adaptyResult(
                        result,
                        profileResult.map { profile -> PurchaseResult.Success(profile) },
                    )
                }
            }
            else -> success(result, purchaseResult)
        }
    }

    private inline fun <reified T: Any> parseJsonArgument(call: MethodCall): T? {
        return try {
            (call.arguments as? String)?.takeIf(String::isNotEmpty)?.let { json ->
                helper.fromJson(json, T::class.java)
            }
        } catch (e: Exception) { null }
    }

    private fun emptyResultOrError(result: MethodChannel.Result, error: AdaptyError?) {
        if (error == null) {
            success(result)
        } else {
            adaptyError(result, error)
        }
    }

    private fun success(result: MethodChannel.Result) {
        result.success(helper.successJson())
    }
    
    private fun success(result: MethodChannel.Result, value: Any?) {
        result.success(value?.let(helper::toSuccessJson))
    }

    private fun adaptyError(result: MethodChannel.Result, error: AdaptyError) {
        result.success(helper.toErrorJson(error))
    }

    private fun callParameterError(
        call: MethodCall,
        result: MethodChannel.Result,
        originalError: Throwable? = null
    ) {
        val message = "Error while parsing parameter"
        val detail =
            "Method: ${call.method}, OriginalError: ${originalError?.localizedMessage ?: originalError?.message}"
        result.success(
            helper.toErrorJson(AdaptyErrorCode.DECODING_FAILED, message, detail)
        )
    }

    private fun uiBridgeError(
        result: MethodChannel.Result,
        bridgeError: AdaptyUiBridgeError,
    ) {
        result.success(
            helper.toErrorJson(bridgeError.rawCode, bridgeError.message)
        )
    }

    private companion object {
        //Method ids
        const val SET_LOG_LEVEL = "set_log_level"
        const val GET_PROFILE = "get_profile"
        const val UPDATE_PROFILE = "update_profile"
        const val ACTIVATE = "activate"
        const val IDENTIFY = "identify"
        const val GET_PAYWALL = "get_paywall"
        const val GET_PAYWALL_FOR_DEFAULT_AUDIENCE = "get_paywall_for_default_audience"
        const val GET_PAYWALL_PRODUCTS = "get_paywall_products"
        const val MAKE_PURCHASE = "make_purchase"
        const val RESTORE_PURCHASES = "restore_purchases"
        const val UPDATE_ATTRIBUTION = "update_attribution"
        const val LOG_SHOW_PAYWALL = "log_show_paywall"
        const val LOG_SHOW_ONBOARDING = "log_show_onboarding"
        const val SET_VARIATION_ID = "set_transaction_variation_id"
        const val SET_FALLBACK_PAYWALLS = "set_fallback_paywalls"
        const val LOGOUT = "logout"
        const val DID_LOAD_LATEST_PROFILE = "did_load_latest_profile"
        const val IS_ACTIVATED = "is_activated"
        const val GET_SDK_VERSION = "get_sdk_version"
        const val ADAPTY_UI_ACTIVATE = "adapty_ui_activate"
        const val ADAPTY_UI_CREATE_VIEW = "adapty_ui_create_view"
        const val ADAPTY_UI_PRESENT_VIEW = "adapty_ui_present_view"
        const val ADAPTY_UI_DISMISS_VIEW = "adapty_ui_dismiss_view"
        const val ADAPTY_UI_SHOW_DIALOG = "adapty_ui_show_dialog"
    }
}