package com.adapty.flutter.models

enum class MethodName(val value: String) {
    ACTIVATE("activate"),
    IDENTIFY("identify"),
    GET_PAYWALLS("get_paywalls"),
    GET_PAYWALLS_RESULT("get_paywalls_result"),
    MAKE_PURCHASE("make_purchase"),
    VALIDATE_PURCHASE("validate_purchase"),
    RESTORE_PURCHASES("restore_purchases"),
    GET_PURCHASER_INFO("get_purchaser_info"),
    GET_ACTIVE_PURCHASES("get_active_purchases"),
    GET_ACTIVE_PURCHASES_RESULT("get_active_purchases_result"),
    UPDATE_ATTRIBUTION("update_attribution"),
    MAKE_DEFERRED_PURCHASE("make_deferred_purchase"),
    PURCHASER_INFO_UPDATE("purchaser_info_update"),
    GET_PROMO("get_promo"),
    PROMO_RECEIVED("promo_received"),
    NEW_PUSH_TOKEN("new_push_token"),
    PUSH_RECEIVED("push_received"),
    LOGOUT("logout"),
    NOT_IMPLEMENTED("not_implemented");

    companion object {

        fun fromValue(value: String) = when (value) {
            ACTIVATE.value -> ACTIVATE
            IDENTIFY.value -> IDENTIFY
            GET_PAYWALLS.value -> GET_PAYWALLS
            GET_PAYWALLS_RESULT.value -> GET_PAYWALLS_RESULT
            MAKE_PURCHASE.value -> MAKE_PURCHASE
            VALIDATE_PURCHASE.value -> VALIDATE_PURCHASE
            RESTORE_PURCHASES.value -> RESTORE_PURCHASES
            GET_PURCHASER_INFO.value -> GET_PURCHASER_INFO
            GET_ACTIVE_PURCHASES.value -> GET_ACTIVE_PURCHASES
            GET_ACTIVE_PURCHASES_RESULT.value -> GET_ACTIVE_PURCHASES_RESULT
            UPDATE_ATTRIBUTION.value -> UPDATE_ATTRIBUTION
            MAKE_DEFERRED_PURCHASE.value -> MAKE_DEFERRED_PURCHASE
            PURCHASER_INFO_UPDATE.value -> PURCHASER_INFO_UPDATE
            GET_PROMO.value -> GET_PROMO
            PROMO_RECEIVED.value -> PROMO_RECEIVED
            NEW_PUSH_TOKEN.value -> NEW_PUSH_TOKEN
            PUSH_RECEIVED.value -> PUSH_RECEIVED
            LOGOUT.value -> LOGOUT
            else -> NOT_IMPLEMENTED
        }
    }
}