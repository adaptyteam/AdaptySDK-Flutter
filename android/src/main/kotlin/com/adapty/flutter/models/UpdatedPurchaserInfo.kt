package com.adapty.flutter.models

data class UpdatedPurchaserInfo(
        val nonSubscriptionsProductIds: List<String>,
        val activePaidAccessLevels: List<String>,
        val activeSubscriptionsIds: List<String>
)