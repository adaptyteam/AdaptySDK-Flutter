package com.adapty.flutter

import android.content.Context
import android.content.pm.PackageManager
import com.adapty.Adapty
import com.adapty.internal.crossplatform.CrossplatformHelper
import com.adapty.internal.crossplatform.CrossplatformName
import com.adapty.internal.crossplatform.MetaInfo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class AdaptyFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    companion object {
        private const val CHANNEL_NAME = "flutter.adapty.com/adapty"
        private const val VERSION = "2.9.2"

        fun registerWith(registrar: PluginRegistry.Registrar) {
            val instance = AdaptyFlutterPlugin();
            instance.callHandler.activity = registrar.activity()
            instance.onAttachedToEngine(registrar.context(), registrar.messenger())
        }
    }

    private lateinit var channel: MethodChannel

    private val crossplatformHelper = kotlin.run {
        CrossplatformHelper.init(MetaInfo.from(CrossplatformName.FLUTTER, VERSION))
        CrossplatformHelper.shared
    }

    private val callHandler = AdaptyCallHandler(crossplatformHelper)

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(
            flutterPluginBinding.applicationContext,
            flutterPluginBinding.binaryMessenger
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        callHandler.onMethodCall(call, result)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onDetachedFromActivity() {
        onNewActivityPluginBinding(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        onNewActivityPluginBinding(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onNewActivityPluginBinding(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onNewActivityPluginBinding(binding)
    }

    private fun onAttachedToEngine(context: Context, binaryMessenger: BinaryMessenger) {
        channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        val metadata = context.packageManager
            .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            .metaData

        activateOnLaunch(
            context,
            metadata?.getString("AdaptyPublicSdkKey").orEmpty(),
            metadata?.getBoolean("AdaptyObserverMode", false) ?: false
        )
    }

    private fun onNewActivityPluginBinding(binding: ActivityPluginBinding?) {
        callHandler.activity = binding?.activity
    }

    private fun activateOnLaunch(context: Context, apiKey: String, observerMode: Boolean) {

        Adapty.activate(context, apiKey, observerMode, null)

        callHandler.handleProfileUpdates(channel)
    }
}
