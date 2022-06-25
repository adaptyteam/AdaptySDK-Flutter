package com.adapty.flutter.models

import com.adapty.errors.AdaptyError
import com.adapty.models.ProductModel
import com.google.gson.annotations.SerializedName

data class VisualPaywallPurchaseFailureResult(
        @SerializedName("product")
        val product: ProductModel,
        @SerializedName("error")
        val error: AdaptyError
)