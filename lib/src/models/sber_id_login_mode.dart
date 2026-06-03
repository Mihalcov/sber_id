/// Native Sber ID authentication entry points (see Sber ID SDK docs).
enum SBerIdLoginMode {
  /// Standard flow: Sber Bank app with web fallback (Android: [loginWithID], iOS: [auth]).
  standard,

  /// OIDC / Custom Tab / Safari (Android: [loginWithIDToCustomTab], iOS: [webAuth]).
  web,

  /// In-app WebView (Android: [loginWithIDToWebView], iOS: [loginWithIDToWebView]).
  webView,

  /// Background auth via Sber app without UI (Android/iOS: [autoAuth]).
  autoAuth,

  /// Seamless SSO from Sber Bank app deeplink ([getSeamlessUriScheme] / [ssoBaseUrl]).
  seamless,
}

extension SBerIdLoginModeExtension on SBerIdLoginMode {
  String get value {
    switch (this) {
      case SBerIdLoginMode.standard:
        return 'standard';
      case SBerIdLoginMode.web:
        return 'web';
      case SBerIdLoginMode.webView:
        return 'webView';
      case SBerIdLoginMode.autoAuth:
        return 'autoAuth';
      case SBerIdLoginMode.seamless:
        return 'seamless';
    }
  }
}
