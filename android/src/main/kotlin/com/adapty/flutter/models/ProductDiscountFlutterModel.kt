package com.adapty.flutter.models

import com.adapty.models.ProductDiscountModel

class ProductDiscountFlutterModel private constructor(
    val price: Double,
    val numberOfPeriods: Int,
    val localizedPrice: String,
    val subscriptionPeriod: ProductSubscriptionPeriodFlutterModel,
    val localizedSubscriptionPeriod: String
) {
    companion object {
        fun from(discount: ProductDiscountModel) = ProductDiscountFlutterModel(
            discount.price.toDouble(),
            discount.numberOfPeriods,
            discount.localizedPrice,
            ProductSubscriptionPeriodFlutterModel.from(discount.subscriptionPeriod),
            discount.localizedSubscriptionPeriod
        )
    }
}