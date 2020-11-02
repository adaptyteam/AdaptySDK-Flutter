package com.adapty.flutter.models

data class AdaptyPromo(
        val id: String,
        val promoType: String,
        val expiresAt: Long,
        val paywallId: String,
        val paywallDeveloperId: String,
        val paywallProducts: List<AdaptyProduct>
)