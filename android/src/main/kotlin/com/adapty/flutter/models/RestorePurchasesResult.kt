package com.adapty.flutter.models

import com.adapty.api.entity.purchaserInfo.model.PurchaserInfoModel
import com.adapty.api.entity.validate.GoogleValidationResult
import com.google.gson.annotations.SerializedName

data class RestorePurchasesResult(
        @SerializedName("purchaserInfo")
        val purchaserInfo: PurchaserInfoModel?,
        @SerializedName("googleValidationResultList")
        val googleValidationResultList: List<GoogleValidationResult>?
)