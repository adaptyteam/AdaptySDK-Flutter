package com.adapty.flutter.serialization

import com.adapty.errors.AdaptyError
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import java.lang.reflect.Type

class AdaptyErrorSerializer : JsonSerializer<AdaptyError> {

    companion object {
        const val ADAPTY_CODE = "adaptyCode"
        const val MESSAGE = "message"
    }

    override fun serialize(
        src: AdaptyError,
        typeOfSrc: Type,
        context: JsonSerializationContext
    ): JsonElement {
        return JsonObject().apply {
            addProperty(ADAPTY_CODE, src.adaptyErrorCode.value)
            addProperty(MESSAGE, src.message.orEmpty())
        }
    }
}