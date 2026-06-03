package com.plugin.sber_id

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Sends native Sber ID button tap events to Flutter ([sber_id/button]). */
object SberIdButtonEvents {
    private const val CHANNEL_NAME = "sber_id/button"

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        EventChannel(messenger, CHANNEL_NAME).setStreamHandler(
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

    fun notifyPressed(viewId: Int) {
        mainHandler.post {
            eventSink?.success(mapOf("viewId" to viewId))
        }
    }
}
