package com.adapty.flutter.models

import com.adapty.models.GoogleValidationResult
import com.adapty.models.PurchaserInfoModel
import com.google.gson.annotations.SerializedName

data class RestorePurchasesResult(
        @SerializedName("purchaserInfo")
        val purchaserInfo: PurchaserInfoModel?,
        @SerializedName("googleValidationResultList")
        val googleValidationResultList: List<GoogleValidationResult>?
)