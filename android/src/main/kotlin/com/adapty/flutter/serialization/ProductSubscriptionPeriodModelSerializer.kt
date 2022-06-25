package com.adapty.flutter.serialization

import com.adapty.models.PeriodUnit
import com.adapty.models.ProductSubscriptionPeriodModel
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import java.lang.reflect.Type

class ProductSubscriptionPeriodModelSerializer : JsonSerializer<ProductSubscriptionPeriodModel> {

    override fun serialize(
        src: ProductSubscriptionPeriodModel,
        typeOfSrc: Type,
        context: JsonSerializationContext
    ): JsonElement {
        return JsonObject().apply {
            addProperty("unit", unitToInt(src.unit))
            addProperty("numberOfUnits", src.numberOfUnits ?: 0)
        }
    }

    private fun unitToInt(unit: PeriodUnit?) = when (unit) {
        PeriodUnit.D -> 0
        PeriodUnit.W -> 1
        PeriodUnit.M -> 2
        PeriodUnit.Y -> 3
        else -> -1
    }
}