import Flutter
import SIDSDK
import UIKit

@objc(SberIdPlugin)
public class SberIdPlugin: NSObject, FlutterPlugin {
    private static var instance: SberIdPlugin?
    private var flutterAuthResult: FlutterResult?
    private var codeVerifier: String?
    private var config: [String: Any]?
    private lazy var webViewDelegate = SberIdWebViewDelegate { [weak self] in
        self?.completeAuthCancelled()
    }

    @objc public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sber_id_auth", binaryMessenger: registrar.messenger())
        let instance = SberIdPlugin()
        SberIdPlugin.instance = instance
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        FlutterEventChannel(name: "sber_id/button", binaryMessenger: registrar.messenger())
            .setStreamHandler(SberIdButtonStreamHandler.shared)
        registrar.register(
            SberIdButtonFactory(messenger: registrar.messenger()),
            withId: "sber_id_button"
        )
        FlutterEventChannel(name: "sber_id/elk", binaryMessenger: registrar.messenger())
            .setStreamHandler(SberIdElkStreamHandler.shared)
        registrar.register(
            SberIdElkFactory(messenger: registrar.messenger()),
            withId: "sber_id_elk"
        )
    }

    @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            runOnMain { self.initialize(call: call, result: result) }
        case "startSberIDAuth":
            runOnMain { self.startSberIDAuth(call: call, result: result) }
        case "isSberIdInstalled":
            runOnMain { self.checkSberIdInstalled(result: result) }
        case "logout":
            runOnMain {
                self.completeAuthCancelled(
                    code: "AUTH_CANCELLED",
                    message: "Authentication cancelled by logout"
                )
                SID.login.logout()
                result(nil)
            }
        case "extractSsoBaseUrl":
            runOnMain { self.extractSsoBaseUrl(call: call, result: result) }
        case "getLaunchSeamlessDeeplink":
            result(nil)
        case "setUserId":
            runOnMain { self.setUserId(call: call, result: result) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let config = call.arguments as? [String: Any],
              let clientId = config["clientId"] as? String,
              let partnerName = config["partnerName"] as? String else {
            result(FlutterError(code: "INVALID_CONFIG", message: "Invalid configuration", details: nil))
            return
        }

        self.config = config
        let stand: SIDStandType = (config["stand"] as? String)?.lowercased() == "cloud_ift" ? .iftCloud : .prom
        let userId = config["userId"] as? String
        let partnerProfileUrl = config["partnerProfileUrl"] as? String

        SID.initializer.initialize(stand: stand) { initResult in
            DispatchQueue.main.async {
                switch initResult {
                case .success:
                    SID.settings.applyMainPreferences(
                        clientID: clientId,
                        userID: userId,
                        partnerName: partnerName,
                        partnerProfileUrl: partnerProfileUrl
                    )
                    result(nil)
                case .fail:
                    result(FlutterError(code: "INIT_FAILED", message: "Sber ID SDK initialization failed", details: nil))
                case .unknown:
                    result(FlutterError(code: "INIT_UNKNOWN", message: "Sber ID SDK initialization finished with unknown status", details: nil))
                @unknown default:
                    result(FlutterError(code: "INIT_UNKNOWN", message: "Sber ID SDK initialization finished with unknown status", details: nil))
                }
            }
        }
    }

    private func startSberIDAuth(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let config = self.config,
              let redirectUri = config["redirectUri"] as? String else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Plugin not initialized", details: nil))
            return
        }

        self.codeVerifier = SIDUtils.createVerifier()
        let codeChallenge = SIDUtils.createChallenge(self.codeVerifier!)
        let codeChallengeMethod = SIDAuthRequest.challengeMethod
        let randomState = UUID().uuidString
        let randomNonce = UUID().uuidString
        let scopes = (config["scopes"] as? [String])?.joined(separator: " ") ?? "openid name email"
        let args = call.arguments as? [String: Any]
        let loginHint = args?["phone"] as? String
        let mode = args?["mode"] as? String ?? "standard"
        let seamlessDeeplink = args?["seamlessDeeplink"] as? String
        let ssoBaseUrl = resolveSsoBaseUrl(
            seamlessDeeplink: seamlessDeeplink,
            explicit: args?["ssoBaseUrl"] as? String
        )

        let request = SIDAuthRequest(
            scope: scopes,
            state: randomState,
            nonce: randomNonce,
            redirectUri: redirectUri,
            ssoBaseUrl: ssoBaseUrl,
            codeChallenge: codeChallenge,
            codeChallengeMethod: codeChallengeMethod,
            loginHint: loginHint
        )

        completeAuthSuperseded()
        self.flutterAuthResult = result

        guard let vc = getRootVC() else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "View controller not found", details: nil))
            self.flutterAuthResult = nil
            return
        }

        switch mode {
        case "web":
            let svcRedirect = args?["customTabRedirectUri"] as? String
                ?? args?["svcRedirectUrlString"] as? String
                ?? redirectUri
            do {
                try SID.login.webAuth(
                    request: request,
                    svcRedirectUrlString: svcRedirect,
                    viewController: vc
                )
            } catch {
                self.completeAuthFailure(
                    code: "AUTH_ERROR",
                    message: error.message ?? "Failed to start web authentication"
                )
            }
        case "webView":
            do {
                try SID.login.loginWithIDToWebView(
                    request: request,
                    viewController: vc,
                    delegate: webViewDelegate
                )
            } catch {
                self.completeAuthFailure(
                    code: "AUTH_ERROR",
                    message: error.message ?? "Failed to start WebView authentication"
                )
            }
        case "autoAuth", "seamless":
            SID.login.autoAuth(request: request) { authResult in
                DispatchQueue.main.async {
                    switch authResult {
                    case .success(let opened) where !opened:
                        self.completeAuthFailure(
                            code: "AUTH_ERROR",
                            message: "autoAuth failed to open Sber app"
                        )
                    case .failure(let error):
                        self.completeAuthFailure(
                            code: "AUTH_ERROR",
                            message: error.message ?? "autoAuth failed to open Sber app"
                        )
                    case .success:
                        break
                    }
                }
            }
        default:
            do {
                try SID.login.auth(request: request, viewController: vc)
            } catch {
                self.completeAuthFailure(
                    code: "AUTH_ERROR",
                    message: error.message ?? "Failed to start Sber ID authentication"
                )
            }
        }
    }

    private func resolveSsoBaseUrl(seamlessDeeplink: String?, explicit: String?) -> String? {
        if let explicit = explicit, !explicit.isEmpty {
            return explicit
        }
        guard let seamlessDeeplink = seamlessDeeplink,
              let url = URL(string: seamlessDeeplink) else {
            return nil
        }
        return SIDUtils.getSSOUrlStringFrom(url)
    }

    private func setUserId(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let config = self.config,
              let clientId = config["clientId"] as? String else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Plugin not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let userId = args["userId"] as? String,
              !userId.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "userId is required", details: nil))
            return
        }
        let partnerName = config["partnerName"] as? String
        let partnerProfileUrl = config["partnerProfileUrl"] as? String
        SID.settings.applyMainPreferences(
            clientID: clientId,
            userID: userId,
            partnerName: partnerName,
            partnerProfileUrl: partnerProfileUrl
        )
        result(nil)
    }

    private func completeAuthSuperseded() {
        guard flutterAuthResult != nil else { return }
        completeAuthCancelled(
            code: "LOGIN_SUPERSEDED",
            message: "Previous login was replaced by a new login request"
        )
    }

    private func completeAuthCancelled(
        code: String = "AUTH_CANCELLED",
        message: String = "Authentication was cancelled"
    ) {
        guard let result = flutterAuthResult else { return }
        result([
            "isSuccess": false,
            "errorCode": code,
            "error": message,
        ])
        flutterAuthResult = nil
        codeVerifier = nil
    }

    private func completeAuthFailure(code: String, message: String) {
        guard let result = flutterAuthResult else { return }
        result([
            "isSuccess": false,
            "errorCode": code,
            "error": message,
        ])
        flutterAuthResult = nil
        codeVerifier = nil
    }

    private func completeAuthSuccess(response: SIDAuthResponse) {
        guard let result = flutterAuthResult else { return }
        result([
            "isSuccess": true,
            "authCode": response.authCode ?? "",
            "state": response.state ?? "",
            "nonce": response.nonce as Any? ?? NSNull(),
            "codeVerifier": codeVerifier as Any? ?? NSNull(),
        ])
        flutterAuthResult = nil
        codeVerifier = nil
    }

    private func extractSsoBaseUrl(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deeplink = args["deeplink"] as? String,
              let url = URL(string: deeplink) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "deeplink is required", details: nil))
            return
        }
        result(SIDUtils.getSSOUrlStringFrom(url))
    }

    private func getRootVC() -> UIViewController? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?.windows
                .first(where: { $0.isKeyWindow })?.rootViewController
        }
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }

    private func checkSberIdInstalled(result: @escaping FlutterResult) {
        let sberSchemes = ["sberbankidexternallogin://", "sbolidexternallogin://"]
        for scheme in sberSchemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                result(true)
                return
            }
        }
        result(false)
    }

    @objc public static func handleURL(_ url: URL) -> Bool {
        return instance?.processRedirectURL(url) ?? false
    }

    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return processRedirectURL(url)
    }

    private func processRedirectURL(_ url: URL) -> Bool {
        guard let config = self.config,
              let redirectUri = config["redirectUri"] as? String,
              let redirectURL = URL(string: redirectUri) else {
            return false
        }

        guard flutterAuthResult != nil else {
            return false
        }

        if url.scheme == redirectURL.scheme && url.host == redirectURL.host {
            SID.login.getResponseFrom(url) { response in
                DispatchQueue.main.async {
                    if response.isSuccess {
                        self.completeAuthSuccess(response: response)
                    } else {
                        self.completeAuthFailure(
                            code: "AUTH_ERROR",
                            message: response.error ?? "Sber ID login failed"
                        )
                    }
                }
            }
            return true
        }

        completeAuthFailure(
            code: "INVALID_REDIRECT",
            message: "Redirect URL scheme or host does not match redirectUri from initialize"
        )
        return true
    }
}
