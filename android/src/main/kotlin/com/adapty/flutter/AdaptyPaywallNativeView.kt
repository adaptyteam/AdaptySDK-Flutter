@file:Suppress("INVISIBLE_MEMBER", "INVISIBLE_REFERENCE")
@file:OptIn(InternalAdaptyApi::class)

package com.adapty.flutter

import android.content.Context
import android.view.View
import androidx.lifecycle.ViewModelStoreOwner
import com.adapty.internal.crossplatform.ui.Dependencies.safeInject
import com.adapty.internal.crossplatform.ui.PaywallUiManager
import com.adapty.internal.utils.InternalAdaptyApi
import com.adapty.internal.utils.log
import com.adapty.ui.AdaptyPaywallView
import com.adapty.utils.AdaptyLogLevel.Companion.ERROR
import io.flutter.plugin.platform.PlatformView

internal class AdaptyPaywallNativeView(
    context: Context,
    id: Int,
    args: Any?,
    private val viewModelStoreOwner: ViewModelStoreOwner,
) : PlatformView {
    private val paywallUiManager: PaywallUiManager? by safeInject<PaywallUiManager>()

    private val paywallView: AdaptyPaywallView = AdaptyPaywallView(context)
        .also { paywallView ->
            val paywallUiManager = paywallUiManager ?: kotlin.run {
                log(ERROR, { "could not find paywallUiManager" })
                return@also
            }
            paywallUiManager.setupPaywallView(paywallView, viewModelStoreOwner, args, "flutter_native_$id")
        }

    override fun getView(): View {
        return paywallView
    }

    override fun dispose() {
        paywallUiManager?.clearPaywallView(paywallView)
    }
}
