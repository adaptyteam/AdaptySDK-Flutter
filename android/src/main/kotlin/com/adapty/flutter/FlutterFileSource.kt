package com.adapty.flutter

/** Where the file named by a custom asset or a fallback comes from. */
internal sealed interface FlutterFileSource {
    data class Asset(val lookupKey: String) : FlutterFileSource
    data class File(val path: String) : FlutterFileSource
}

internal fun flutterFileSource(value: String, lookupKey: (String) -> String): FlutterFileSource =
    FlutterFileSource.Asset(lookupKey(value))
