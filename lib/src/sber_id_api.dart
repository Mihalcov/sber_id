import 'models/auth_response.dart';
import 'models/sber_id_config.dart';
import 'models/sber_id_login_mode.dart';
import 'models/sber_id_login_options.dart';
import '../sber_id_platform_interface.dart';

/// Entry point for Sber ID authentication on iOS and Android.
///
/// Call [initialize] once, then [login]. Send [SBerIdAuthResponse.authCode]
/// and [SBerIdAuthResponse.codeVerifier] to your backend (PKCE).
class SBerId {
  SBerId._();
  static final SBerId instance = SBerId._();

  /// Applies [config] to the native Sber ID SDK. Call once before [login].
  Future<void> initialize(SBerIdConfig config) async {
    return SBerIdPlatform.instance.initialize(config);
  }

  /// Starts Sber ID authentication. Completes with [SBerIdAuthResponse]
  /// (including failures). Does not throw on a cancelled or failed login.
  Future<SBerIdAuthResponse?> login({
    SBerIdLoginOptions options = const SBerIdLoginOptions(),
    String? phone,
    SBerIdLoginMode? mode,
    String? ssoBaseUrl,
    String? customTabRedirectUri,
  }) async {
    return SBerIdPlatform.instance.login(
      options: SBerIdLoginOptions(
        mode: mode ?? options.mode,
        phone: phone ?? options.phone,
        ssoBaseUrl: ssoBaseUrl ?? options.ssoBaseUrl,
        customTabRedirectUri: customTabRedirectUri ?? options.customTabRedirectUri,
      ),
    );
  }

  /// Whether the Sber Bank app can be opened for native login.
  Future<bool> isSBerIdInstalled() async {
    return SBerIdPlatform.instance.isSBerIdInstalled();
  }

  /// Ends the native Sber ID session.
  Future<void> logout() async {
    return SBerIdPlatform.instance.logout();
  }

  /// Parses [deeplink] from Sber Bank (parameter sberIDRedirect) into SSO base URL.
  Future<String?> extractSsoBaseUrl(String deeplink) {
    return SBerIdPlatform.instance.extractSsoBaseUrl(deeplink);
  }

  /// Deeplink on cold start when opened from Sber Bank for seamless SSO (Android).
  Future<String?> getLaunchSeamlessDeeplink() {
    return SBerIdPlatform.instance.getLaunchSeamlessDeeplink();
  }

  /// Auth result saved after redirect when Activity/engine was recreated (Android).
  Future<SBerIdAuthResponse?> takePendingAuthResult() {
    return SBerIdPlatform.instance.takePendingAuthResult();
  }

  /// Sets partner user id for ELK (call after successful login).
  Future<void> setUserId(String userId) {
    return SBerIdPlatform.instance.setUserId(userId);
  }

  /// Seamless login after transition from Sber Bank app.
  Future<SBerIdAuthResponse?> loginSeamless({
    required String seamlessDeeplink,
    String? phone,
  }) async {
    final ssoBaseUrl = await extractSsoBaseUrl(seamlessDeeplink);
    return login(
      options: SBerIdLoginOptions(
        mode: SBerIdLoginMode.seamless,
        seamlessDeeplink: seamlessDeeplink,
        ssoBaseUrl: ssoBaseUrl,
        phone: phone,
      ),
    );
  }
}
