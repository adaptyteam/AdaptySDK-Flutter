package com.adapty.flutter

/** Where the file named by a custom asset or a fallback comes from. */
internal sealed interface FlutterFileSource {
    data class Asset(val lookupKey: String) : FlutterFileSource
    data class File(val path: String) : FlutterFileSource
}

/**
 * A Flutter asset key is always relative, so a name that starts with a slash is an absolute file path.
 */
internal fun flutterFileSource(value: String, lookupKey: (String) -> String): FlutterFileSource =
    if (value.startsWith("/")) FlutterFileSource.File(value) else FlutterFileSource.Asset(lookupKey(value))
