package com.plugin.sber_id

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import sid.sdk.core.auth.init.SIDLogin
import sid.sdk.core.auth.pkce.PkceUtils
import sid.sdk.core.global.models.StandName
import sid.sdk.core.init.SID
import sid.sdk.elk.init.SIDELK
import java.security.SecureRandom
import java.util.UUID

/** Flutter plugin for Sber ID (SIDSDK_CORE). */
class SberIdPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var clientId: String? = null
    private var redirectUri: String? = null
    private var scopes: List<String>? = null
    private var standName: StandName = StandName.PROM
    private var pendingResult: Result? = null
    private var codeVerifier: String? = null
    private var authInProgress = false
    private var wasPausedDuringAuth = false
    private var lifecycleObserver: DefaultLifecycleObserver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sber_id_auth")
        channel.setMethodCallHandler(this)
        SberIdButtonEvents.register(flutterPluginBinding.binaryMessenger)
        SberIdElkEvents.register(flutterPluginBinding.binaryMessenger)
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "sber_id_button",
            SberIdButtonFactory(),
        )
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "sber_id_elk",
            SberIdElkFactory(),
        )
        SID.Initializer.initialize(
            application = flutterPluginBinding.applicationContext as android.app.Application,
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "startSberIDAuth" -> startSberIDAuth(call, result)
            "isSberIdInstalled" -> result.success(isSberIdInstalled())
            "logout" -> {
                cancelPendingAuth("AUTH_CANCELLED", "Authentication cancelled by logout")
                SIDLogin.logout()
                result.success(null)
            }
            "extractSsoBaseUrl" -> extractSsoBaseUrl(call, result)
            "getLaunchSeamlessDeeplink" -> getLaunchSeamlessDeeplink(result)
            "setUserId" -> setUserId(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: Result) {
        clientId = call.argument<String>("clientId")
        redirectUri = call.argument<String>("redirectUri")
        scopes = call.argument<List<String>>("scopes")
        standName = when ((call.argument<String>("stand") ?: "prom").lowercase()) {
            "cloud_ift" -> StandName.CLOUD_IFT
            else -> StandName.PROM
        }
        val userId = call.argument<String>("userId")
        val partnerProfileUrl = call.argument<String>("partnerProfileUrl")

        if (clientId == null) {
            result.error("INVALID_ARGUMENT", "clientId is required", null)
            return
        }

        SID.Settings.setMainSettings(
            clientID = clientId!!,
            userID = userId,
            stand = standName,
        )

        partnerProfileUrl?.let { SIDELK.setProfileUrl(it) }

        result.success(null)
    }

    private fun startSberIDAuth(call: MethodCall, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        val redirect = redirectUri
        if (redirect.isNullOrEmpty()) {
            result.error("NOT_INITIALIZED", "redirectUri is required; call initialize first", null)
            return
        }

        cancelPendingAuth(
            "LOGIN_SUPERSEDED",
            "Previous login was replaced by a new login request",
        )
        pendingResult = result
        authInProgress = true
        try {
            codeVerifier = PkceUtils.generateRandomCodeVerifier(SecureRandom())
            val codeChallenge = PkceUtils.deriveCodeVerifierChallenge(codeVerifier!!)
            val state = UUID.randomUUID().toString()
            val nonce = UUID.randomUUID().toString()
            val scope = scopes?.joinToString(" ") ?: "openid name email"
            val phone = call.argument<String>("phone")
            val mode = call.argument<String>("mode") ?: "standard"
            val seamlessDeeplink = call.argument<String>("seamlessDeeplink")
            val ssoBaseUrl = call.argument<String>("ssoBaseUrl")
            val customTabRedirectUri = call.argument<String>("customTabRedirectUri") ?: ""
            val uriScheme = resolveUriScheme(redirect, seamlessDeeplink, ssoBaseUrl)

            val uri = SIDLogin.createLoginUri(
                scope,
                state,
                nonce,
                redirect,
                customTabRedirectUri,
                codeChallenge,
                PkceUtils.getCodeChallengeMethod(),
                uriScheme,
                phone ?: "",
                null,
            )

            val started = when (mode) {
                "web" -> SIDLogin.loginWithIDToCustomTab(currentActivity, uri)
                "webView" -> SIDLogin.loginWithIDToWebView(currentActivity, uri)
                "autoAuth", "seamless" -> SIDLogin.autoAuth(uri)
                else -> {
                    val fragmentActivity = currentActivity as? FragmentActivity
                        ?: throw IllegalStateException("Activity must extend FragmentActivity for standard login")
                    SIDLogin.loginWithID(fragmentActivity, uri) == true
                }
            }

            if (!started && mode != "standard") {
                failPendingAuth("AUTH_ERROR", "Failed to start Sber ID authentication")
            } else if (!started) {
                failPendingAuth("AUTH_ERROR", "Failed to start Sber ID authentication")
            }
        } catch (e: Exception) {
            val message = e.message ?: "Failed to start Sber ID authentication"
            val code = if (e is IllegalStateException) "NO_ACTIVITY" else "AUTH_ERROR"
            failPendingAuth(code, message)
        }
    }

    private fun cancelPendingAuth(errorCode: String, message: String) {
        val pending = pendingResult ?: return
        pending.success(
            mapOf(
                "isSuccess" to false,
                "errorCode" to errorCode,
                "error" to message,
            ),
        )
        clearAuthState()
    }

    private fun failPendingAuth(errorCode: String, message: String) {
        pendingResult?.error(errorCode, message, null)
        clearAuthState()
    }

    private fun clearAuthState() {
        pendingResult = null
        codeVerifier = null
        authInProgress = false
        wasPausedDuringAuth = false
    }

    private fun intentMatchesRedirect(intent: Intent?): Boolean {
        val data = intent?.data ?: return false
        val redirect = redirectUri ?: return false
        val expected = Uri.parse(redirect)
        return data.scheme == expected.scheme && data.host == expected.host
    }

    private fun onActivityResumed() {
        if (pendingResult == null || !authInProgress || !wasPausedDuringAuth) return
        wasPausedDuringAuth = false
        val intent = activity?.intent
        if (intent?.data == null) {
            cancelPendingAuth(
                "AUTH_CANCELLED",
                "Authentication was cancelled (user closed web or returned without redirect)",
            )
        }
    }

    private fun redirectUriToScheme(redirect: String): String {
        val parsed = Uri.parse(redirect)
        val host = parsed.host ?: "redirect"
        val scheme = parsed.scheme ?: "partner"
        return "$scheme://$host"
    }

    private fun resolveUriScheme(
        redirect: String,
        seamlessDeeplink: String?,
        ssoBaseUrl: String?,
    ): String {
        if (!seamlessDeeplink.isNullOrEmpty()) {
            val seamless = Uri.parse(seamlessDeeplink)
            SIDLogin.getSeamlessUriScheme(seamless)?.let { return it }
        }
        if (!ssoBaseUrl.isNullOrEmpty()) {
            return ssoBaseUrl
        }
        return redirectUriToScheme(redirect)
    }

    private fun extractSsoBaseUrl(call: MethodCall, result: Result) {
        val deeplink = call.argument<String>("deeplink")
        if (deeplink.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "deeplink is required", null)
            return
        }
        try {
            val scheme = SIDLogin.getSeamlessUriScheme(Uri.parse(deeplink))
            result.success(scheme)
        } catch (e: Exception) {
            result.error("SSO_ERROR", e.message, null)
        }
    }

    private fun setUserId(call: MethodCall, result: Result) {
        val userId = call.argument<String>("userId")
        if (userId.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "userId is required", null)
            return
        }
        val clientId = this.clientId
        if (clientId == null) {
            result.error("NOT_INITIALIZED", "call initialize first", null)
            return
        }
        SID.Settings.setMainSettings(
            clientID = clientId,
            userID = userId,
            stand = standName,
        )
        result.success(null)
    }

    private fun getLaunchSeamlessDeeplink(result: Result) {
        val data = activity?.intent?.data
        if (data == null) {
            result.success(null)
            return
        }
        try {
            val scheme = SIDLogin.getSeamlessUriScheme(data)
            if (scheme.isNullOrEmpty()) {
                result.success(null)
            } else {
                result.success(data.toString())
            }
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun isSberIdInstalled(): Boolean {
        val pm = activity?.packageManager ?: return false
        return try {
            pm.getPackageInfo("ru.sberbankmobile", 0)
            true
        } catch (_: Exception) {
            try {
                pm.getPackageInfo("ru.sberbank_sbbol", 0)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun handleAuthIntent(intent: Intent?) {
        if (intent == null || pendingResult == null) return
        if (intent.data != null && !intentMatchesRedirect(intent)) {
            cancelPendingAuth(
                "INVALID_REDIRECT",
                "Redirect URL scheme or host does not match redirectUri from initialize",
            )
            return
        }
        try {
            val resultModel = SIDLogin.getIDAuthResult(intent)
            if (resultModel.isSuccess == true) {
                pendingResult?.success(
                    mapOf(
                        "isSuccess" to true,
                        "authCode" to resultModel.authCode,
                        "state" to resultModel.state,
                        "nonce" to resultModel.nonce,
                        "codeVerifier" to codeVerifier,
                    ),
                )
            } else {
                pendingResult?.success(
                    mapOf(
                        "isSuccess" to false,
                        "errorCode" to "AUTH_ERROR",
                        "error" to (resultModel.errorDescription ?: "Sber ID login failed"),
                    ),
                )
            }
        } catch (e: Exception) {
            pendingResult?.success(
                mapOf(
                    "isSuccess" to false,
                    "errorCode" to "AUTH_ERROR",
                    "error" to (e.message ?: "Sber ID login failed"),
                ),
            )
        }
        clearAuthState()
    }

    override fun onNewIntent(intent: Intent): Boolean {
        handleAuthIntent(intent)
        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        attachLifecycleObserver(binding)
        handleAuthIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachLifecycleObserver()
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        attachLifecycleObserver(binding)
        handleAuthIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivity() {
        detachLifecycleObserver()
        activity = null
        activityBinding = null
    }

    private fun attachLifecycleObserver(binding: ActivityPluginBinding) {
        detachLifecycleObserver()
        val observer = object : DefaultLifecycleObserver {
            override fun onPause(owner: LifecycleOwner) {
                if (authInProgress) {
                    wasPausedDuringAuth = true
                }
            }

            override fun onResume(owner: LifecycleOwner) {
                onActivityResumed()
            }
        }
        lifecycleObserver = observer
        val owner = binding.activity as? LifecycleOwner
        if (owner == null) {
            lifecycleObserver = null
            return
        }
        owner.lifecycle.addObserver(observer)
    }

    private fun detachLifecycleObserver() {
        lifecycleObserver?.let { observer ->
            (activity as? LifecycleOwner)?.lifecycle?.removeObserver(observer)
        }
        lifecycleObserver = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
