package com.adapty.flutter.models

import com.adapty.models.PaywallModel
import com.adapty.models.ProductModel
import com.google.gson.annotations.SerializedName

data class GetPaywallsResult(
        @SerializedName("paywalls")
        val paywalls: List<PaywallModel>,
        @SerializedName("products")
        val products: List<ProductModel>
)