package com.adapty.flutter.models

import com.adapty.api.entity.paywalls.ProductModel

class ProductSubscriptionPeriodFlutterModel private constructor(
        var unit: Int,
        var numberOfUnits: Int
) {
    companion object {
        fun from(periodModel: ProductModel.ProductSubscriptionPeriodModel) = ProductSubscriptionPeriodFlutterModel(
                unit = unitToInt(periodModel.unit),
                numberOfUnits = periodModel.numberOfUnits ?: 0
        )

        private fun unitToInt(unit: ProductModel.PeriodUnit?) = when (unit) {
            ProductModel.PeriodUnit.D -> 0
            ProductModel.PeriodUnit.W -> 1
            ProductModel.PeriodUnit.M -> 2
            ProductModel.PeriodUnit.Y -> 3
            else -> -1
        }
    }
}