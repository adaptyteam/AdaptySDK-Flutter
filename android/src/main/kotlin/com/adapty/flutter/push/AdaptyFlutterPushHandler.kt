package com.adapty.flutter.push

import android.content.Context
import com.adapty.flutter.R
import com.adapty.push.AdaptyPushHandler

class AdaptyFlutterPushHandler(context: Context) : AdaptyPushHandler(context) {

    override val clickAction = "ADAPTY_PROMO_CLICK_ACTION"

    override val smallIconResId = R.drawable.ic_adapty_promo_push
}