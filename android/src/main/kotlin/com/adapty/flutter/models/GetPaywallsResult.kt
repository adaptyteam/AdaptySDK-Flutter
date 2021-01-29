package com.adapty.flutter.models

import com.google.gson.annotations.SerializedName

data class GetPaywallsResult(
        @SerializedName("paywalls")
        val paywalls: List<PaywallFlutterModel>,
        @SerializedName("products")
        val products: List<ProductFlutterModel>
)