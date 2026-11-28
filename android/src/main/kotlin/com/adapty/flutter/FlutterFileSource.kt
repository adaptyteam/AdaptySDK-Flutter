package com.adapty.flutter

import java.io.File

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

/**
 * The location of the file named by [value]: [fromFile] makes it from the file of an absolute path, [fromAsset] from the
 * lookup key of any other name among the Flutter assets.
 */
internal fun <L> flutterFileLocation(
    value: String,
    lookupKey: (String) -> String,
    fromAsset: (String) -> L,
    fromFile: (File) -> L,
): L =
    when (val source = flutterFileSource(value, lookupKey)) {
        is FlutterFileSource.Asset -> fromAsset(source.lookupKey)
        is FlutterFileSource.File -> fromFile(File(source.path))
    }
