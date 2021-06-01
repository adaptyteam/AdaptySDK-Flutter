package com.adapty.flutter.models

import com.adapty.models.PeriodUnit
import com.adapty.models.ProductSubscriptionPeriodModel

class ProductSubscriptionPeriodFlutterModel private constructor(
        var unit: Int,
        var numberOfUnits: Int
) {
    companion object {
        fun from(periodModel: ProductSubscriptionPeriodModel) = ProductSubscriptionPeriodFlutterModel(
                unit = unitToInt(periodModel.unit),
                numberOfUnits = periodModel.numberOfUnits ?: 0
        )

        private fun unitToInt(unit: PeriodUnit?) = when (unit) {
            PeriodUnit.D -> 0
            PeriodUnit.W -> 1
            PeriodUnit.M -> 2
            PeriodUnit.Y -> 3
            else -> -1
        }
    }
}