package com.adapty.flutter.models

import com.adapty.models.PaywallModel
import com.google.gson.annotations.SerializedName

class PaywallFlutterModel private constructor(
    @SerializedName("developerId")
    val developerId: String,
    @SerializedName("name")
    val name: String?,
    @SerializedName("abTestName")
    val abTestName: String?,
    @SerializedName("revision")
    val revision: Int,
    @SerializedName("isPromo")
    val isPromo: Boolean,
    @SerializedName("variationId")
    val variationId: String,
    @SerializedName("products")
    val products: ArrayList<ProductFlutterModel>,
    @SerializedName("customPayloadString")
    val customPayloadString: String?
) {

    companion object {
        fun from(paywall: PaywallModel) = PaywallFlutterModel(
            developerId = paywall.developerId,
            name = paywall.name,
            abTestName = paywall.abTestName,
            revision = paywall.revision,
            isPromo = paywall.isPromo,
            variationId = paywall.variationId,
            customPayloadString = paywall.customPayloadString,
            products = paywall.products.mapTo(ArrayList(), ProductFlutterModel.Companion::from)
        )
    }
}