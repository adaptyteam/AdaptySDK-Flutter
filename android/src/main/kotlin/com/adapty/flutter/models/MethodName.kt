package com.adapty.flutter.models

enum class MethodName(val value: String) {
    IDENTIFY("identify"),
    SET_LOG_LEVEL("set_log_level"),
    LOG_SHOW_PAYWALL("log_show_paywall"),
    GET_PAYWALLS("get_paywalls"),
    GET_PAYWALLS_RESULT("get_paywalls_result"),
    MAKE_PURCHASE("make_purchase"),
    VALIDATE_PURCHASE("validate_purchase"),
    RESTORE_PURCHASES("restore_purchases"),
    GET_PURCHASER_INFO("get_purchaser_info"),
    UPDATE_ATTRIBUTION("update_attribution"),
    UPDATE_PROFILE("update_profile"),
    PURCHASER_INFO_UPDATE("purchaser_info_update"),
    GET_PROMO("get_promo"),
    PROMO_RECEIVED("promo_received"),
    NEW_PUSH_TOKEN("new_push_token"),
    PUSH_RECEIVED("push_received"),
    SET_TRANSACTION_VARIATION_ID("set_transaction_variation_id"),
    SET_EXTERNAL_ANALYTICS_ENABLED("set_external_analytics_enabled"),
    LOGOUT("logout"),
    SHOW_VISUAL_PAYWALL("show_visual_paywall"),
    CLOSE_VISUAL_PAYWALL("close_visual_paywall"),
    VISUAL_PAYWALL_CLOSED_RESULT("visual_paywall_closed_result"),
    VISUAL_PAYWALL_PURCHASE_SUCCESS_RESULT("visual_paywall_purchase_success_result"),
    VISUAL_PAYWALL_PURCHASE_FAILURE_RESULT("visual_paywall_purchase_failure_result"),
    VISUAL_PAYWALL_RESTORE_PURCHASES_RESULT("visual_paywall_restore_purchases_result"),
    NOT_IMPLEMENTED("not_implemented");

    companion object {

        fun fromValue(value: String) = when (value) {
            IDENTIFY.value -> IDENTIFY
            SET_LOG_LEVEL.value -> SET_LOG_LEVEL
            LOG_SHOW_PAYWALL.value -> LOG_SHOW_PAYWALL
            GET_PAYWALLS.value -> GET_PAYWALLS
            GET_PAYWALLS_RESULT.value -> GET_PAYWALLS_RESULT
            MAKE_PURCHASE.value -> MAKE_PURCHASE
            VALIDATE_PURCHASE.value -> VALIDATE_PURCHASE
            RESTORE_PURCHASES.value -> RESTORE_PURCHASES
            GET_PURCHASER_INFO.value -> GET_PURCHASER_INFO
            UPDATE_ATTRIBUTION.value -> UPDATE_ATTRIBUTION
            UPDATE_PROFILE.value -> UPDATE_PROFILE
            PURCHASER_INFO_UPDATE.value -> PURCHASER_INFO_UPDATE
            GET_PROMO.value -> GET_PROMO
            PROMO_RECEIVED.value -> PROMO_RECEIVED
            NEW_PUSH_TOKEN.value -> NEW_PUSH_TOKEN
            PUSH_RECEIVED.value -> PUSH_RECEIVED
            SET_TRANSACTION_VARIATION_ID.value -> SET_TRANSACTION_VARIATION_ID
            SET_EXTERNAL_ANALYTICS_ENABLED.value -> SET_EXTERNAL_ANALYTICS_ENABLED
            LOGOUT.value -> LOGOUT
            SHOW_VISUAL_PAYWALL.value -> SHOW_VISUAL_PAYWALL
            CLOSE_VISUAL_PAYWALL.value -> CLOSE_VISUAL_PAYWALL
            VISUAL_PAYWALL_CLOSED_RESULT.value -> VISUAL_PAYWALL_CLOSED_RESULT
            VISUAL_PAYWALL_PURCHASE_SUCCESS_RESULT.value -> VISUAL_PAYWALL_PURCHASE_SUCCESS_RESULT
            VISUAL_PAYWALL_PURCHASE_FAILURE_RESULT.value -> VISUAL_PAYWALL_PURCHASE_FAILURE_RESULT
            VISUAL_PAYWALL_RESTORE_PURCHASES_RESULT.value -> VISUAL_PAYWALL_RESTORE_PURCHASES_RESULT
            else -> NOT_IMPLEMENTED
        }
    }
}