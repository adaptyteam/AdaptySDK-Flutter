package com.adapty.flutter

import android.app.Activity
import android.content.Context
import android.view.View
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModelStoreOwner
import androidx.savedstate.SavedStateRegistryOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject

internal class AdaptyFlowNativeViewFactory(
    private val currentActivity: () -> Activity?,
    private val sendEvent: (eventName: String, eventData: String) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val activity = currentActivity()
        if (activity is ViewModelStoreOwner && activity is LifecycleOwner && activity is SavedStateRegistryOwner) {
            return AdaptyFlowNativeView(context, viewId, args, activity, sendEvent)
        }
        return UnsupportedHostFlowView(context, viewId, args, activity, sendEvent)
    }
}

/** An empty view that reports why the flow can't be shown: no activity, or one that can't host it. */
private class UnsupportedHostFlowView(
    context: Context,
    id: Int,
    args: Any?,
    activity: Activity?,
    sendEvent: (eventName: String, eventData: String) -> Unit,
) : PlatformView {
    private val view = View(context)

    init {
        val flow = runCatching { JSONObject(args as String).getJSONObject("flow") }.getOrNull()
        val placementId = flow?.optJSONObject("placement")?.optString("developer_id").orEmpty()
        val variationId = flow?.optString("variation_id").orEmpty()
        val message = if (activity == null) {
            "AdaptyUIFlowPlatformView has no activity to show the flow in"
        } else {
            "AdaptyUIFlowPlatformView needs an activity that extends FlutterFragmentActivity"
        }
        val event = JSONObject()
            .put("id", EVENT_ID)
            .put("view", JSONObject()
                .put("id", "flutter_native_$id")
                .put("placement_id", placementId)
                .put("variation_id", variationId))
            .put("error", JSONObject()
                .put("adapty_code", 4001)
                .put("message", message)
                .put("detail", "activity: ${activity?.javaClass?.name ?: "none"}"))
        android.util.Log.e("Adapty", message)
        sendEvent(EVENT_ID, event.toString())
    }

    override fun getView(): View = view

    override fun dispose() = Unit

    private companion object {
        const val EVENT_ID = "flow_view_did_receive_error"
    }
}
