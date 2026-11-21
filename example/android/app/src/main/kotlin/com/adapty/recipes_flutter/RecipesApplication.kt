package com.adapty.recipes_flutter

import android.app.Application
import android.widget.TextView
import com.adapty.ui.AdaptyCustomElementContent
import com.adapty.ui.AdaptyCustomElementsResolver
import com.adapty.ui.AdaptyUI

// Named in AndroidManifest.xml in place of ${applicationName}, which Flutter fills with
// android.app.Application.
class RecipesApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Flows draw their custom elements with the resolver registered here. An element whose
        // custom type it does not serve shows the fallback set for it in the Adapty Flow Builder.
        AdaptyUI.setCustomElementsResolver(
            AdaptyCustomElementsResolver { type, id ->
                if (type == "example_badge") {
                    AdaptyCustomElementContent.view(factory = { context, _ ->
                        TextView(context).apply { text = "Drawn by the app: $id" }
                    })
                } else {
                    null
                }
            }
        )
    }
}
