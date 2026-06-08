package com.plugin.sber_id

import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import sid.sdk.core.auth.model.SIDButtonModel
import sid.sdk.core.auth.view.SIDButton

class SberIdButtonFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?>
        val width = (params?.get("width") as? Number)?.toInt() ?: 300
        val height = (params?.get("height") as? Number)?.toInt() ?: 60
        val cornerRadius = (params?.get("cornerRadius") as? Number)?.toInt() ?: 4
        val clientId = params?.get("clientId") as? String

        val model = SIDButtonModel(
            clientId,
            width,
            height,
            null,
            null,
            cornerRadius,
            null,
            false,
        )
        // SIDButton needs a visual Context (Activity), not ApplicationContext.
        val button = SIDButton(context, null, 0, model)
        button.setOnClickListener {
            SberIdButtonEvents.notifyPressed(viewId)
        }
        return object : PlatformView {
            override fun getView(): View = button
            override fun dispose() {}
        }
    }
}
