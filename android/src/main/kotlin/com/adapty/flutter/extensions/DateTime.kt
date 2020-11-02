package com.adapty.flutter.extensions

import java.text.SimpleDateFormat
import java.util.*

private const val UTC_TIME_ZONE = "UTC"

fun String.toTimestamp(
        format: String,
        timeZone: TimeZone = TimeZone.getTimeZone(UTC_TIME_ZONE),
        locale: Locale = Locale.getDefault()
): Long = toDate(format, timeZone, locale).time

fun String.toDate(
        format: String,
        timeZone: TimeZone = TimeZone.getTimeZone(UTC_TIME_ZONE),
        locale: Locale = Locale.getDefault()
): Date = format.toDateFormat(locale).apply { this.timeZone = timeZone }.parse(this) ?: Date()

fun String.toDateFormat(locale: Locale = Locale.getDefault()) = SimpleDateFormat(this, locale)