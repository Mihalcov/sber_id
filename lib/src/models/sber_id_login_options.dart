import 'sber_id_login_mode.dart';

/// Options for a single login attempt.
class SBerIdLoginOptions {
  final SBerIdLoginMode mode;

  /// Login hint / phone in format 79XXXXXXXXX.
  final String? phone;

  /// Seamless SSO base URL / uriScheme (iOS [ssoBaseUrl], Android [uriScheme] in createLoginUri).
  final String? ssoBaseUrl;

  /// Incoming deeplink from Sber Bank app (contains sberIDRedirect). Parsed natively.
  final String? seamlessDeeplink;

  /// Custom Tab return URL for OIDC (Android customTabRedirectUri, iOS svcRedirectUrlString).
  final String? customTabRedirectUri;

  const SBerIdLoginOptions({
    this.mode = SBerIdLoginMode.standard,
    this.phone,
    this.ssoBaseUrl,
    this.seamlessDeeplink,
    this.customTabRedirectUri,
  });

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.value,
      if (phone != null) 'phone': phone,
      if (ssoBaseUrl != null) 'ssoBaseUrl': ssoBaseUrl,
      if (seamlessDeeplink != null) 'seamlessDeeplink': seamlessDeeplink,
      if (customTabRedirectUri != null) ...{
        'customTabRedirectUri': customTabRedirectUri,
        'svcRedirectUrlString': customTabRedirectUri,
      },
    };
  }
}
