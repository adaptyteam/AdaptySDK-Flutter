package com.adapty.flutter.models

import com.adapty.api.entity.purchaserInfo.model.PurchaserInfoModel
import com.google.gson.annotations.SerializedName

data class GetPurchaserInfoResult(
        @SerializedName("purchaserInfo")
        val purchaserInfo: PurchaserInfoModel?,
        @SerializedName("dataState")
        val state: Int
)