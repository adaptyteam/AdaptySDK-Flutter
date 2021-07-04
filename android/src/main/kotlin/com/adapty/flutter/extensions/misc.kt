package com.adapty.flutter.extensions

import com.adapty.models.Date
import com.adapty.models.Gender
import com.adapty.models.SubscriptionUpdateParamModel
import com.adapty.models.SubscriptionUpdateParamModel.ProrationMode
import com.adapty.utils.ProfileParameterBuilder

inline fun <reified T: Any> ProfileParameterBuilder.addIfNeeded(
        arg: Any?,
        body: ProfileParameterBuilder.(T) -> ProfileParameterBuilder
) : ProfileParameterBuilder {
    return (arg as? T)?.let {
        this.body(it)
    } ?: this
}

fun Map<String, Any>?.toProfileParamBuilder(): ProfileParameterBuilder {
    return ProfileParameterBuilder()
            .addIfNeeded<String>(this?.get("amplitude_device_id"), ProfileParameterBuilder::withAmplitudeDeviceId)
            .addIfNeeded<String>(this?.get("amplitude_user_id"), ProfileParameterBuilder::withAmplitudeUserId)
            .addIfNeeded<String>(this?.get("email"), ProfileParameterBuilder::withEmail)
            .addIfNeeded<String>(this?.get("phone_number"), ProfileParameterBuilder::withPhoneNumber)
            .addIfNeeded<String>(this?.get("facebook_user_id"), ProfileParameterBuilder::withFacebookUserId)
            .addIfNeeded<String>(this?.get("facebook_anonymous_id"), ProfileParameterBuilder::withFacebookAnonymousId)
            .addIfNeeded<String>(this?.get("mixpanel_user_id"), ProfileParameterBuilder::withMixpanelUserId)
            .addIfNeeded<String>(this?.get("appmetrica_profile_id"), ProfileParameterBuilder::withAppmetricaProfileId)
            .addIfNeeded<String>(this?.get("appmetrica_device_id"), ProfileParameterBuilder::withAppmetricaDeviceId)
            .addIfNeeded<String>(this?.get("first_name"), ProfileParameterBuilder::withFirstName)
            .addIfNeeded<String>(this?.get("last_name"), ProfileParameterBuilder::withLastName)
            .addIfNeeded<String>(this?.get("gender")) { gender ->
                withGender(
                        when (gender) {
                            "f" -> Gender.FEMALE
                            "m" -> Gender.MALE
                            else -> Gender.OTHER
                        }
                )
            }
            .addIfNeeded<String>(this?.get("birthday")) { birthdayStr ->
                try {
                    birthdayStr.split("-").takeIf { it.size == 3 }?.let {
                        withBirthday(Date(it[0].toInt(), it[1].toInt(), it[2].toInt()))
                    } ?: this
                } catch (e: Exception) {
                    this
                }
            }
            .addIfNeeded<Map<String, Any>>(this?.get("custom_attributes"), ProfileParameterBuilder::withCustomAttributes)
}

fun Map<String, String>.toSubscriptionUpdateParamModel(): SubscriptionUpdateParamModel? {
    val oldVendorProductId = this["old_sub_vendor_product_id"]
    val prorationMode = when (this["proration_mode"]) {
        "immediateAndChargeFullPrice" -> ProrationMode.IMMEDIATE_AND_CHARGE_FULL_PRICE
        "deferred" -> ProrationMode.DEFERRED
        "immediateWithoutProration" -> ProrationMode.IMMEDIATE_WITHOUT_PRORATION
        "immediateAndChargeProratedPrice" -> ProrationMode.IMMEDIATE_AND_CHARGE_PRORATED_PRICE
        "immediateWithTimeProration" -> ProrationMode.IMMEDIATE_WITH_TIME_PRORATION
        else -> null
    }
    return safeLet(
        oldVendorProductId,
        prorationMode
    ) { oldVendorProductId, prorationMode ->
        SubscriptionUpdateParamModel(oldVendorProductId, prorationMode)
    }
}

fun <T1 : Any, T2 : Any, R : Any> safeLet(p1: T1?, p2: T2?, block: (T1, T2) -> R?): R? =
    if (p1 != null && p2 != null) block(p1, p2) else null