package com.adapty.flutter.registrant

import com.adapty.flutter.AdaptyFlutterPlugin
import io.flutter.plugin.common.PluginRegistry

object AdaptyPluginRegistrant {

    fun registerWith(registry: PluginRegistry?) {
        if (alreadyRegisteredWith(registry)) {
            return
        }
        registry?.registrarFor("com.adapty.flutter.AdaptyFlutterPlugin")?.let { registrar ->
            AdaptyFlutterPlugin.registerWith(registrar)
        }
    }

    private fun alreadyRegisteredWith(registry: PluginRegistry?): Boolean {
        val key: String? = AdaptyPluginRegistrant::class.java.canonicalName
        if (registry?.hasPlugin(key)!!) {
            return true
        }
        registry.registrarFor(key)
        return false
    }
}