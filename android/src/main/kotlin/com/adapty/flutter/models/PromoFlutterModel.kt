package com.adapty.flutter.models

import com.adapty.api.entity.paywalls.PromoModel

class PromoFlutterModel private constructor(
        var promoType: String?,
        var variationId: String?,
        var expiresAt: String?,
        var paywall: PaywallFlutterModel?
) {

    companion object {
        fun from(promo: PromoModel) = PromoFlutterModel(
                promo.promoType,
                promo.variationId,
                promo.expiresAt,
                promo.paywall?.let(PaywallFlutterModel.Companion::from)
        )
    }
}