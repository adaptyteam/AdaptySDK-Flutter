package com.adapty.flutter.models

enum class SourceType(val value: String) {
    ADJUST("adjust"),
    APPSFLYER("appsflyer"),
    BRANCH("branch"),
    CUSTOM("custom");

    companion object {

        fun fromValue(value: String?) = when (value) {
            ADJUST.value -> ADJUST
            APPSFLYER.value -> APPSFLYER
            BRANCH.value -> BRANCH
            CUSTOM.value -> CUSTOM
            else -> null
        }
    }
}