package com.adapty.flutter.push

import android.content.Context
import com.adapty.push.AdaptyPushHandler

class AdaptyFlutterPushHandler(
    context: Context,
    override val clickAction: String,
    override val smallIconResId: Int
) : AdaptyPushHandler(context)