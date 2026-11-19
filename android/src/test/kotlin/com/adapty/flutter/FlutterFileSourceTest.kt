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
}
