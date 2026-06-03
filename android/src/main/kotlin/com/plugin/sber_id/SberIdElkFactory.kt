package com.plugin.sber_id

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import sid.sdk.elk.presentation.container.ELKContainerView

class SberIdElkFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?>
        val containerName = params?.get("containerName") as? String
        val containerVersion = (params?.get("containerVersion") as? Number)?.toInt()
        val horizontalPadding = (params?.get("horizontalPadding") as? Number)?.toInt() ?: 0
        val heightPx = (params?.get("height") as? Number)?.toInt()

        val elkView = ELKContainerView(context)
        containerName?.let { elkView.setContainerName(it) }
        containerVersion?.let { elkView.setContainerVersion(it) }
        if (horizontalPadding > 0) {
            elkView.setDimensions(
                sid.sdk.global.models.SIDDimensionsELK(
                    elkHorizontalPadding = horizontalPadding,
                ),
            )
        }
        elkView.subscribeOnContainerEvents { event ->
            SberIdElkEvents.notifyEvent(viewId, event)
        }

        val wrapper = FrameLayout(context)
        val layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            heightPx ?: FrameLayout.LayoutParams.WRAP_CONTENT,
        )
        wrapper.addView(elkView, layoutParams)

        return object : PlatformView {
            override fun getView(): View = wrapper
            override fun dispose() {}
        }
    }
}
