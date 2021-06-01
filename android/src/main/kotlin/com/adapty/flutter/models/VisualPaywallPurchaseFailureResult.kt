package com.adapty.flutter.models

import com.google.gson.annotations.SerializedName

data class VisualPaywallPurchaseFailureResult(
        @SerializedName("product")
        val product: ProductFlutterModel,
        @SerializedName("error")
        val error: AdaptyFlutterError
)