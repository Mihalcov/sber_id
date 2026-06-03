package com.plugin.sber_id

import io.flutter.plugin.common.EventChannel
import sid.sdk.elk.utils.events.ELKEvents

object SberIdElkEvents {
    private var eventSink: EventChannel.EventSink? = null

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger) {
        EventChannel(messenger, "sber_id/elk").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    fun notifyEvent(viewId: Int, event: ELKEvents) {
        val payload = when (event) {
            is ELKEvents.ClickELK -> mapOf(
                "viewId" to viewId,
                "type" to "click",
                "widgetName" to event.widgetName,
            )
            is ELKEvents.ShowELK -> mapOf("viewId" to viewId, "type" to "show")
            is ELKEvents.HideELK -> mapOf("viewId" to viewId, "type" to "hide")
            is ELKEvents.ErrorELK -> mapOf("viewId" to viewId, "type" to "error")
            is ELKEvents.ReloadELK -> mapOf("viewId" to viewId, "type" to "reload")
            is ELKEvents.WidgetErrorELK -> mapOf(
                "viewId" to viewId,
                "type" to "widgetError",
                "widgetName" to event.widgetName,
                "httpStatusCode" to event.httpStatusCode,
                "partnerErrorCode" to event.partnerErrorCode,
            )
            is ELKEvents.OpenWidgetELK -> mapOf(
                "viewId" to viewId,
                "type" to "openWidget",
                "widgetName" to event.widgetName,
            )
            is ELKEvents.ShowWidgetELK -> mapOf(
                "viewId" to viewId,
                "type" to "showWidget",
                "widgetName" to event.widgetName,
            )
            else -> mapOf("viewId" to viewId, "type" to "unknown")
        }
        eventSink?.success(payload)
    }
}
