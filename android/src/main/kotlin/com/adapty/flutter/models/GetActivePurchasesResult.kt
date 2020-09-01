package com.adapty.flutter.models

data class GetActivePurchasesResult(
        val activeSubscription: Boolean,
        val activeSubscriptionProductId: String?,
        val nonSubscriptionsProductIds: List<String>
)