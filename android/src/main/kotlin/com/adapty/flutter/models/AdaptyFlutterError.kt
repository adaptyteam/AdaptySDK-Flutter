package com.adapty.flutter.models

import com.adapty.api.AdaptyError
import com.adapty.api.AdaptyErrorCode
import com.google.gson.annotations.SerializedName

class AdaptyFlutterError private constructor(
        @SerializedName("adaptyCode")
        val adaptyCode: Int,
        @SerializedName("message")
        val message: String
) {
    companion object {
        fun from(error: AdaptyError) = AdaptyFlutterError(mapErrorCode(error.adaptyErrorCode), error.message)

        fun from(code: AdaptyErrorCode, message: String) = AdaptyFlutterError(mapErrorCode(code), message)

        private fun mapErrorCode(adaptyErrorCode: AdaptyErrorCode) = when (adaptyErrorCode) {
            AdaptyErrorCode.USER_CANCELED -> 2
            AdaptyErrorCode.ITEM_UNAVAILABLE -> 5
            AdaptyErrorCode.EMPTY_PARAMETER -> 2007
            AdaptyErrorCode.AUTHENTICATION_ERROR -> 2002
            AdaptyErrorCode.BAD_REQUEST -> 2003
            AdaptyErrorCode.REQUEST_OUTDATED -> 2004
            AdaptyErrorCode.REQUEST_FAILED -> 2005
            else -> adaptyErrorCode.value * 10
        }
    }
}