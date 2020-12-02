package com.adapty.flutter.extensions

import com.adapty.api.entity.DataState
import com.adapty.api.entity.profile.update.Date
import com.adapty.api.entity.profile.update.Gender
import com.adapty.api.entity.profile.update.ProfileParameterBuilder
import java.lang.Exception

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

fun DataState.toInt() = if (this == DataState.SYNCED) 1 else 0