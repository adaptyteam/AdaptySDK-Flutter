package com.adapty.flutter.example

import android.content.Intent
import android.os.Bundle
import com.adapty.flutter.AdaptyFlutterPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        AdaptyFlutterPlugin.handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        AdaptyFlutterPlugin.handleIntent(intent)
    }
}
