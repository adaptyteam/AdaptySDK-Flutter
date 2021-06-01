package com.adapty.flutter.models

import com.adapty.models.ProductModel
import com.android.billingclient.api.SkuDetails

class ProductFlutterModel private constructor(
    val vendorProductId: String,
    val localizedTitle: String,
    val localizedDescription: String,
    val paywallName: String?,
    val paywallABTestName: String?,
    val variationId: String?,
    val price: Double,
    val localizedPrice: String?,
    val currencyCode: String?,
    val currencySymbol: String?,
    val subscriptionPeriod: ProductSubscriptionPeriodFlutterModel?,
    val introductoryOfferEligibility: Boolean,
    val introductoryDiscount: ProductDiscountFlutterModel?,
    val freeTrialPeriod: ProductSubscriptionPeriodFlutterModel?,
    val skuDetails: SkuDetails?
) {

    companion object {
        fun from(product: ProductModel) = ProductFlutterModel(
            vendorProductId = product.vendorProductId,
            localizedTitle = product.localizedTitle,
            localizedDescription = product.localizedDescription,
            variationId = product.variationId,
            paywallName = product.paywallName,
            paywallABTestName = product.paywallABTestName,
            price = product.price.toDouble(),
            localizedPrice = product.localizedPrice,
            currencyCode = product.currencyCode,
            currencySymbol = product.currencySymbol,
            subscriptionPeriod = product.subscriptionPeriod?.let(
                ProductSubscriptionPeriodFlutterModel.Companion::from
            ),
            introductoryOfferEligibility = product.introductoryOfferEligibility,
            introductoryDiscount = product.introductoryDiscount?.let(ProductDiscountFlutterModel.Companion::from),
            freeTrialPeriod = product.freeTrialPeriod?.let(ProductSubscriptionPeriodFlutterModel.Companion::from),
            skuDetails = product.skuDetails
        )
    }
}