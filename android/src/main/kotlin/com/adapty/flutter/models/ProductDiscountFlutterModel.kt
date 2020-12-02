package com.adapty.flutter.models

import com.adapty.api.entity.paywalls.ProductModel

class ProductDiscountFlutterModel private constructor(
        var price: Double,
        var numberOfPeriods: Int,
        var localizedPrice: String,
        var subscriptionPeriod : ProductSubscriptionPeriodFlutterModel
) {
    companion object {
        fun from(discount: ProductModel.ProductDiscountModel) = ProductDiscountFlutterModel(
                discount.price.toDouble(),
                discount.numberOfPeriods,
                discount.localizedPrice,
                ProductSubscriptionPeriodFlutterModel.from(discount.subscriptionPeriod)
        )
    }
}