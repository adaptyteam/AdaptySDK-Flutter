package com.adapty.flutter

import android.content.Context
import com.adapty.internal.crossplatform.CrossplatformHelper
import com.adapty.utils.FileLocation
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class AdaptyFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    companion object {
        private const val CHANNEL_NAME = "flutter.adapty.com/adapty"
    }

    private var channel: MethodChannel? = null

    private val crossplatformHelper by lazy {
        CrossplatformHelper.shared
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(
            flutterPluginBinding.applicationContext,
            flutterPluginBinding.binaryMessenger
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        crossplatformHelper.onMethodCall(call.arguments, call.method) { data ->
            result.success(data)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        crossplatformHelper.release()
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
        if (channel == null) {
            channel = MethodChannel(binaryMessenger, CHANNEL_NAME).also { channel ->
                channel.setMethodCallHandler(this)
            }
        }
        CrossplatformHelper.init(
            context,
            { eventName, eventData -> channel?.invokeMethod(eventName, eventData) },
            { value -> FileLocation.fromAsset(FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(value)) },
        )
    }

    private fun onNewActivityPluginBinding(binding: ActivityPluginBinding?) {
        crossplatformHelper.setActivity { binding?.activity }
    }
}
