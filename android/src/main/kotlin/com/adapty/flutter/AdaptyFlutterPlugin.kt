package com.adapty.flutter

import android.app.Application
import android.content.Context
import com.adapty.internal.crossplatform.CrossplatformHelper
import com.adapty.internal.crossplatform.CrossplatformName
import com.adapty.internal.crossplatform.MetaInfo
import com.adapty.internal.crossplatform.ui.CrossplatformUiHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry

class AdaptyFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    companion object {
        private const val CHANNEL_NAME = "flutter.adapty.com/adapty"
        private const val VERSION = "3.3.0"

        fun registerWith(registrar: PluginRegistry.Registrar) {
            val instance = AdaptyFlutterPlugin();
            instance.callHandler.activity = registrar.activity()
            instance.onAttachedToEngine(registrar.context(), registrar.messenger())
        }
    }

    private var channel: MethodChannel? = null

    private val crossplatformHelper = kotlin.run {
        CrossplatformHelper.init(MetaInfo.from(CrossplatformName.FLUTTER, VERSION))
        CrossplatformHelper.shared
    }

    private val callHandler by lazy {
        AdaptyCallHandler(
            crossplatformHelper,
            CrossplatformUiHelper.shared,
        )
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(
            flutterPluginBinding.applicationContext,
            flutterPluginBinding.binaryMessenger
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        channel?.let { channel -> callHandler.onMethodCall(call, result, channel) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
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
        if (CrossplatformUiHelper.init(context) || channel == null) {
            channel = MethodChannel(binaryMessenger, CHANNEL_NAME).also { channel ->
                channel.setMethodCallHandler(this)
            }
        }

        with(callHandler) {
            appContext = if (context is Application) context else context.applicationContext
            channel?.let {channel -> handleUiEvents(channel) }
        }
    }

    private fun onNewActivityPluginBinding(binding: ActivityPluginBinding?) {
        callHandler.activity = binding?.activity
    }
}
