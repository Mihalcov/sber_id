package com.plugin.sber_id

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
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
import android.os.Handler
import android.os.Looper

/** Flutter plugin for Sber ID (SIDSDK_CORE). */
class SberIdPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener {
    companion object {
        private const val TAG = "SberIdPlugin"
        private const val PREFS_NAME = "sber_id_auth"
        private const val PKCE_PREFS_NAME = "sber_id_pkce"
        private const val PKCE_KEY = "verifier"
        private const val PREF_AUTH_CODE = "pending_auth_code"
        private const val PREF_AUTH_STATE = "pending_auth_state"

        @Volatile
        private var appContext: Context? = null

        @Volatile
        private var persistedCodeVerifier: String? = null

        @Volatile
        private var persistedRedirectUri: String? = null

        @Volatile
        private var persistedAuthResult: Map<String, Any?>? = null

        private fun prefs(): android.content.SharedPreferences? {
            val ctx = appContext ?: return null
            return ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        private fun ensureAppContext(context: Context?) {
            if (appContext == null && context != null) {
                appContext = context.applicationContext
            }
        }

        private fun pkcePrefs(): android.content.SharedPreferences? {
            val ctx = appContext ?: return null
            return ctx.getSharedPreferences(PKCE_PREFS_NAME, Context.MODE_PRIVATE)
        }

        private fun saveCodeVerifier(verifier: String, context: Context? = null) {
            ensureAppContext(context)
            persistedCodeVerifier = verifier
            val prefs = pkcePrefs()
            val ok = prefs?.edit()?.putString(PKCE_KEY, verifier)?.commit() == true
            val readBack = prefs?.getString(PKCE_KEY, null)
            Log.d(
                TAG,
                "saveCodeVerifier len=${verifier.length} commit=$ok readBack=${readBack?.length ?: -1}",
            )
        }

        private fun loadCodeVerifier(context: Context? = null): String? {
            ensureAppContext(context)
            val memory = persistedCodeVerifier
            if (!memory.isNullOrEmpty()) return memory
            val stored = pkcePrefs()?.getString(PKCE_KEY, null)
            if (!stored.isNullOrEmpty()) {
                persistedCodeVerifier = stored
            }
            return stored
        }

        private fun clearCodeVerifierStorage() {
            persistedCodeVerifier = null
            pkcePrefs()?.edit()?.remove(PKCE_KEY)?.commit()
        }

        private fun clearStalePendingAuthCode() {
            persistedAuthResult = null
            prefs()?.edit()
                ?.remove(PREF_AUTH_CODE)
                ?.remove(PREF_AUTH_STATE)
                ?.commit()
        }

        private fun persistPendingAuthToStorage(payload: Map<String, Any?>) {
            val prefs = prefs() ?: return
            prefs.edit()
                .putString(PREF_AUTH_CODE, payload["authCode"] as? String)
                .putString(PREF_AUTH_STATE, payload["state"] as? String)
                .commit()
        }

        private fun loadPendingAuthFromStorage(): Map<String, Any?>? {
            val prefs = prefs() ?: return null
            val code = prefs.getString(PREF_AUTH_CODE, null)?.trim()
            if (code.isNullOrEmpty()) return null
            return mapOf(
                "isSuccess" to true,
                "authCode" to code,
                "state" to prefs.getString(PREF_AUTH_STATE, null),
                "codeVerifier" to loadCodeVerifier(),
            )
        }

        private fun clearPendingAuthStorage() {
            clearStalePendingAuthCode()
            clearCodeVerifierStorage()
        }

        private fun enrichPayloadWithVerifier(
            payload: Map<String, Any?>,
            context: Context? = null,
        ): Map<String, Any?> {
            val verifier = payload["codeVerifier"] as? String
            if (!verifier.isNullOrEmpty()) return payload
            val stored = loadCodeVerifier(context) ?: return payload
            return payload + mapOf("codeVerifier" to stored)
        }

        private fun discardOrphanPendingAuthWithoutVerifier(context: Context? = null) {
            ensureAppContext(context)
            val stored = persistedAuthResult ?: loadPendingAuthFromStorage() ?: return
            val enriched = enrichPayloadWithVerifier(stored, context)
            if (enriched["isSuccess"] == true &&
                (enriched["codeVerifier"] as? String).isNullOrEmpty()
            ) {
                Log.d(TAG, "discard orphan pending auth without PKCE verifier")
                clearStalePendingAuthCode()
            }
        }

        private fun takePersistedAuthResult(): Map<String, Any?>? {
            val result = persistedAuthResult ?: loadPendingAuthFromStorage() ?: return null
            val enriched = enrichPayloadWithVerifier(result)
            if (enriched["isSuccess"] == true) {
                val verifier = enriched["codeVerifier"] as? String
                if (verifier.isNullOrEmpty()) {
                    Log.d(TAG, "takePending: discarding auth code without PKCE verifier")
                    clearStalePendingAuthCode()
                    return null
                }
            }
            persistedAuthResult = null
            clearPendingAuthStorage()
            return enriched
        }

        private fun clearPersistedAuth() {
            persistedAuthResult = null
            clearPendingAuthStorage()
        }
    }
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
    private val mainHandler = Handler(Looper.getMainLooper())
    private var resumeCheckRunnable: Runnable? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
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
                clearPersistedAuth()
                SIDLogin.logout()
                result.success(null)
            }
            "extractSsoBaseUrl" -> extractSsoBaseUrl(call, result)
            "getLaunchSeamlessDeeplink" -> getLaunchSeamlessDeeplink(result)
            "takePendingAuthResult" -> result.success(takePersistedAuthResult())
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

        redirectUri?.let { persistedRedirectUri = it }
        discardOrphanPendingAuthWithoutVerifier(activity)
        result.success(null)
    }

    private fun startSberIDAuth(call: MethodCall, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        takePersistedAuthResult()?.let { stored ->
            result.success(stored)
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
        clearStalePendingAuthCode()
        pendingResult = result
        authInProgress = true
        try {
            codeVerifier = PkceUtils.generateRandomCodeVerifier(SecureRandom())
            saveCodeVerifier(codeVerifier!!, currentActivity)
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
        cancelResumeCheck()
        pendingResult = null
        codeVerifier = null
        authInProgress = false
        wasPausedDuringAuth = false
    }

    private fun cancelResumeCheck() {
        resumeCheckRunnable?.let { mainHandler.removeCallbacks(it) }
        resumeCheckRunnable = null
    }

    private fun intentMatchesRedirect(intent: Intent?): Boolean {
        val data = intent?.data ?: return false
        val redirect = redirectUri ?: persistedRedirectUri ?: return true
        val expected = Uri.parse(redirect)
        return data.scheme == expected.scheme && data.host == expected.host
    }

    private fun onActivityResumed() {
        if (pendingResult == null || !authInProgress || !wasPausedDuringAuth) return
        wasPausedDuringAuth = false
        cancelResumeCheck()

        val intent = activity?.intent
        if (intent?.data != null && intentMatchesRedirect(intent)) {
            handleAuthIntent(intent)
            return
        }

        if (deliverPersistedToPendingLogin()) return

        // Redirect from the Sber app often arrives after onResume. Cancelling
        // earlier drops the code into storage while Dart already shows an error.
        resumeCheckRunnable = Runnable {
            if (pendingResult == null || !authInProgress) return@Runnable
            val delayedIntent = activity?.intent
            if (delayedIntent?.data != null && intentMatchesRedirect(delayedIntent)) {
                handleAuthIntent(delayedIntent)
            } else if (!deliverPersistedToPendingLogin()) {
                cancelPendingAuth(
                    "AUTH_CANCELLED",
                    "Authentication was cancelled (user closed web or returned without redirect)",
                )
            }
        }
        mainHandler.postDelayed(resumeCheckRunnable!!, 12000L)
    }

    private fun deliverPersistedToPendingLogin(): Boolean {
        if (pendingResult == null) return false
        if (persistedAuthResult == null && loadPendingAuthFromStorage() == null) return false
        val stored = takePersistedAuthResult() ?: return false
        Log.d(TAG, "resume: delivering persisted auth result to login()")
        pendingResult?.success(stored)
        clearRedirectFromActivityIntent()
        clearAuthState()
        return true
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

    private fun clearRedirectFromActivityIntent() {
        val act = activity ?: return
        if (act.intent?.data == null) return
        act.setIntent(
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                setClassName(act.packageName, act.componentName.className)
            },
        )
    }

    private fun deliverAuthPayload(payload: Map<String, Any?>) {
        val enriched = enrichPayloadWithVerifier(payload, activity)
        if (enriched["isSuccess"] == true) {
            val verifier = enriched["codeVerifier"] as? String
            if (verifier.isNullOrEmpty()) {
                val existing = persistedAuthResult ?: loadPendingAuthFromStorage()
                if (existing != null) {
                    val existingEnriched = enrichPayloadWithVerifier(existing, activity)
                    val existingVerifier = existingEnriched["codeVerifier"] as? String
                    if (!existingVerifier.isNullOrEmpty()) {
                        Log.d(TAG, "deliverAuthPayload keep existing auth with verifier")
                        return
                    }
                }
                Log.d(TAG, "deliverAuthPayload skip: auth code without PKCE verifier")
                return
            }
        }
        val pending = pendingResult
        if (pending != null) {
            Log.d(TAG, "deliverAuthPayload to pending login()")
            pending.success(enriched)
            clearRedirectFromActivityIntent()
            clearAuthState()
            return
        }
        if (enriched["isSuccess"] == true) {
            Log.d(
                TAG,
                "deliverAuthPayload persisted for Dart recovery " +
                    "(verifier=${(enriched["codeVerifier"] as? String)?.length ?: 0} chars)",
            )
            persistedAuthResult = enriched
            persistPendingAuthToStorage(enriched)
            clearRedirectFromActivityIntent()
            clearAuthState()
        }
    }

    /** Sber Bank app redirect: pes://auth?code=…&state=…&result=SUCCESS */
    private fun authPayloadFromRedirectUri(data: Uri, verifier: String?): Map<String, Any?>? {
        val code = data.getQueryParameter("code")?.trim()
        if (code.isNullOrEmpty()) return null
        val result = data.getQueryParameter("result")?.trim()?.uppercase()
        if (result != null && result != "SUCCESS") return null
        return mapOf(
            "isSuccess" to true,
            "authCode" to code,
            "state" to data.getQueryParameter("state"),
            "nonce" to data.getQueryParameter("nonce"),
            "codeVerifier" to verifier,
        )
    }

    private fun handleAuthIntent(intent: Intent?) {
        if (intent == null) return
        ensureAppContext(activity)
        val data = intent.data
        if (data != null) {
            val redirect = redirectUri ?: persistedRedirectUri
            if (redirect != null && !intentMatchesRedirect(intent)) {
                if (pendingResult != null) {
                    cancelPendingAuth(
                        "INVALID_REDIRECT",
                        "Redirect URL scheme or host does not match redirectUri from initialize",
                    )
                }
                return
            }
        } else if (pendingResult == null) {
            return
        }
        cancelResumeCheck()
        val verifier = codeVerifier ?: loadCodeVerifier(activity)

        if (data != null) {
            authPayloadFromRedirectUri(data, verifier)?.let { payload ->
                Log.d(TAG, "auth from redirect URI query params")
                deliverAuthPayload(payload)
                return
            }
        }

        try {
            val resultModel = SIDLogin.getIDAuthResult(intent)
            val payload = if (resultModel.isSuccess == true) {
                mapOf(
                    "isSuccess" to true,
                    "authCode" to resultModel.authCode,
                    "state" to resultModel.state,
                    "nonce" to resultModel.nonce,
                    "codeVerifier" to verifier,
                )
            } else {
                mapOf(
                    "isSuccess" to false,
                    "errorCode" to "AUTH_ERROR",
                    "error" to (resultModel.errorDescription ?: "Sber ID login failed"),
                )
            }
            if (payload["isSuccess"] == true) {
                Log.d(TAG, "auth from SIDLogin.getIDAuthResult")
                deliverAuthPayload(payload)
            } else if (pendingResult != null) {
                pendingResult?.success(payload)
                clearAuthState()
            }
        } catch (e: Exception) {
            Log.w(TAG, "getIDAuthResult failed: ${e.message}")
            if (data != null) {
                authPayloadFromRedirectUri(data, verifier)?.let { payload ->
                    deliverAuthPayload(payload)
                    return
                }
            }
            val pending = pendingResult
            if (pending != null) {
                pending.success(
                    mapOf(
                        "isSuccess" to false,
                        "errorCode" to "AUTH_ERROR",
                        "error" to (e.message ?: "Sber ID login failed"),
                    ),
                )
                clearAuthState()
            }
        }
    }

    override fun onNewIntent(intent: Intent): Boolean {
        activity?.setIntent(intent)
        handleAuthIntent(intent)
        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        ensureAppContext(binding.activity)
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        attachLifecycleObserver(binding)
        discardOrphanPendingAuthWithoutVerifier(binding.activity)
        handleAuthIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachLifecycleObserver()
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        ensureAppContext(binding.activity)
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        attachLifecycleObserver(binding)
        discardOrphanPendingAuthWithoutVerifier(binding.activity)
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
