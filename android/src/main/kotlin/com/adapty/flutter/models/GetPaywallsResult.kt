package com.adapty.flutter.models

data class GetPaywallsResult(
        val paywalls: List<String>,
        val products: List<AdaptyProduct>
)