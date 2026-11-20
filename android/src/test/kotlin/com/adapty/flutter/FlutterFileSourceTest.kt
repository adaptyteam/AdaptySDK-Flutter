package com.adapty.flutter

import org.junit.Assert.assertEquals
import org.junit.Test

class FlutterFileSourceTest {

    private val lookupKey: (String) -> String = { "flutter_assets/$it" }

    @Test
    fun `an asset key is looked up among the Flutter assets`() {
        for (key in listOf("images/a.png", "packages/x/a.png", "a/b.png")) {
            assertEquals(FlutterFileSource.Asset("flutter_assets/$key"), flutterFileSource(key, lookupKey))
        }
    }

    @Test
    fun `an absolute path is read as a file`() {
        assertEquals(
            FlutterFileSource.File("/data/user/0/app/cache/a.png"),
            flutterFileSource("/data/user/0/app/cache/a.png", lookupKey),
        )
    }

    @Test
    fun `the root path alone is read as a file`() {
        assertEquals(FlutterFileSource.File("/"), flutterFileSource("/", lookupKey))
    }

    @Test
    fun `an absolute path with spaces is read as a file as it is`() {
        assertEquals(
            FlutterFileSource.File("/data/user/0/app/cache/my image.png"),
            flutterFileSource("/data/user/0/app/cache/my image.png", lookupKey),
        )
    }

    @Test
    fun `a relative path with a slash inside or a leading dot is looked up among the Flutter assets`() {
        for (key in listOf("a/b.png", "./a.png")) {
            assertEquals(FlutterFileSource.Asset("flutter_assets/$key"), flutterFileSource(key, lookupKey))
        }
    }

    @Test
    fun `a file URI is still looked up among the Flutter assets`() {
        assertEquals(
            FlutterFileSource.Asset("flutter_assets/file:///data/user/0/app/cache/a.png"),
            flutterFileSource("file:///data/user/0/app/cache/a.png", lookupKey),
        )
    }
}
