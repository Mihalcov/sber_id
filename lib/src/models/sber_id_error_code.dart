/// Stable error codes returned from native Sber ID SDK via MethodChannel.
abstract final class SBerIdErrorCode {
  static const authCancelled = 'AUTH_CANCELLED';
  static const authError = 'AUTH_ERROR';
  static const initFailed = 'INIT_FAILED';
  static const invalidArgument = 'INVALID_ARGUMENT';
  static const invalidConfig = 'INVALID_CONFIG';
  static const invalidRedirect = 'INVALID_REDIRECT';
  static const loginSuperseded = 'LOGIN_SUPERSEDED';
  static const noActivity = 'NO_ACTIVITY';
  static const noViewController = 'NO_VIEW_CONTROLLER';
  static const notInitialized = 'NOT_INITIALIZED';
  static const ssoError = 'SSO_ERROR';
  static const unknown = 'UNKNOWN';
}
