package com.adapty.flutter.serialization

import com.adapty.models.PaywallModel
import com.android.billingclient.api.SkuDetails
import com.google.gson.ExclusionStrategy
import com.google.gson.FieldAttributes

class SerializationExclusionStrategy : ExclusionStrategy {

    override fun shouldSkipField(f: FieldAttributes): Boolean {
        return f.declaringClass == PaywallModel::class.java && f.name == "customPayload"
    }

    override fun shouldSkipClass(clazz: Class<*>): Boolean {
        return clazz == SkuDetails::class.java
    }
}