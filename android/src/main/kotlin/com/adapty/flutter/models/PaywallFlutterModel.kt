package com.adapty.flutter.models

import com.adapty.api.entity.paywalls.PaywallModel
import com.google.gson.annotations.SerializedName

class PaywallFlutterModel {
    @SerializedName("developerId")
    var developerId: String? = null

    @SerializedName("revision")
    var revision: Int? = null

    @SerializedName("isPromo")
    var isPromo: Boolean? = null

    @SerializedName("variationId")
    var variationId: String? = null

    @SerializedName("products")
    var products: ArrayList<ProductFlutterModel>? = null

    @SerializedName("customPayload")
    var customPayload: String? = null

    companion object {
        fun from(paywall: PaywallModel) = PaywallFlutterModel().apply {
            developerId = paywall.developerId
            revision = paywall.revision
            isPromo = paywall.isPromo
            variationId = paywall.variationId
            customPayload = paywall.customPayload
            products = paywall.products?.mapTo(ArrayList(), ProductFlutterModel.Companion::from)
        }
    }
}