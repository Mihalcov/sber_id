package com.plugin.sber_id

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito

internal class SberIdPluginTest {
  @Test
  fun onMethodCall_unknownMethod_returnsNotImplemented() {
    val plugin = SberIdPlugin()
    val call = MethodCall("unknown", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)
    Mockito.verify(mockResult).notImplemented()
  }

  @Test
  fun onMethodCall_initialize_withoutClientId_returnsError() {
    val plugin = SberIdPlugin()
    val call = MethodCall("initialize", mapOf("redirectUri" to "app://auth"))
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)
    Mockito.verify(mockResult).error(
      Mockito.eq("INVALID_ARGUMENT"),
      Mockito.eq("clientId is required"),
      Mockito.isNull(),
    )
  }
}
