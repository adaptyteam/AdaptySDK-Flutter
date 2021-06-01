package com.adapty.flutter.models

import com.adapty.errors.AdaptyError
import com.adapty.errors.AdaptyErrorCode
import com.google.gson.annotations.SerializedName

class AdaptyFlutterError private constructor(
        @SerializedName("adaptyCode")
        val adaptyCode: Int,
        @SerializedName("message")
        val message: String
) {
    companion object {
        fun from(error: AdaptyError) = AdaptyFlutterError(error.adaptyErrorCode.value, error.message ?: "")

        fun from(code: AdaptyErrorCode, message: String) = AdaptyFlutterError(code.value, message)
    }
}