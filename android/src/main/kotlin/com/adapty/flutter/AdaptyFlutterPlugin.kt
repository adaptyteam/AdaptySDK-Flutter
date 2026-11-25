package com.adapty.flutter

import android.app.Activity
import android.content.Context
import androidx.lifecycle.ViewModelStoreOwner
import com.adapty.internal.crossplatform.ActivityProvider
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

        // The plugin instances, one per Flutter engine, that have an activity, in the order they
        // got it. The native SDK is shared by all engines of the process and uses the activity of
        // the last one, so an engine that loses its activity, such as the engine of an old activity
        // destroyed after a new one has started, doesn't take the activity away from the others.
        private val pluginsWithActivity = mutableListOf<AdaptyFlutterPlugin>()

        private val activityProvider = ActivityProvider {
            synchronized(pluginsWithActivity) { pluginsWithActivity.lastOrNull()?.activity }
        }
    }

    private var channel: MethodChannel? = null

    private var activity: Activity? = null
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    private val crossplatformHelper by lazy {
        CrossplatformHelper.shared
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = flutterPluginBinding
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "adaptyui_flow_platform_view",
            AdaptyFlowNativeViewFactory({ activity }) { eventName, eventData ->
                channel?.invokeMethod(eventName, eventData)
            }
        )
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
        pluginBinding = null
        crossplatformHelper.release(this)
    }

    override fun onDetachedFromActivity() {
        updateActivity(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        updateActivity(binding.activity)
        registerViewFactory()
    }

    private fun registerViewFactory() {
        val registry = pluginBinding?.platformViewRegistry ?: return
        val viewModelStoreOwner = activity as? ViewModelStoreOwner ?: return

        registry.registerViewFactory(
            "adaptyui_onboarding_platform_view",
            AdaptyOnboardingNativeViewFactory(viewModelStoreOwner)
        )
        
    }

    override fun onDetachedFromActivityForConfigChanges() {
        updateActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        updateActivity(binding.activity)
    }

    private fun onAttachedToEngine(context: Context, binaryMessenger: BinaryMessenger) {
        if (channel == null) {
            channel = MethodChannel(binaryMessenger, CHANNEL_NAME).also { channel ->
                channel.setMethodCallHandler(this)
            }
        }
        CrossplatformHelper.init(
            this,
            context,
            { eventName, eventData -> channel?.invokeMethod(eventName, eventData) },
            { value -> FileLocation.fromAsset(FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(value)) },
        )
    }

    private fun updateActivity(activity: Activity?) {
        synchronized(pluginsWithActivity) {
            this.activity = activity
            pluginsWithActivity.remove(this)
            if (activity != null) pluginsWithActivity.add(this)
        }
        crossplatformHelper.setActivity(activityProvider)
    }
}
