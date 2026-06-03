import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'sber_id_method_channel.dart';
import 'src/models/auth_response.dart';
import 'src/models/sber_id_config.dart';
import 'src/models/sber_id_login_options.dart';

abstract class SBerIdPlatform extends PlatformInterface {
  SBerIdPlatform() : super(token: _token);

  static final Object _token = Object();
  static SBerIdPlatform _instance = MethodChannelSBerId();

  static SBerIdPlatform get instance => _instance;

  static set instance(SBerIdPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(SBerIdConfig config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<SBerIdAuthResponse?> login({SBerIdLoginOptions options = const SBerIdLoginOptions()}) {
    throw UnimplementedError('login() has not been implemented.');
  }

  Future<bool> isSBerIdInstalled() {
    throw UnimplementedError('isSberIdInstalled() has not been implemented.');
  }

  Future<void> logout() {
    throw UnimplementedError('logout() has not been implemented.');
  }

  /// Extracts SSO base URL / uriScheme from a seamless deeplink (Sber Bank → partner app).
  Future<String?> extractSsoBaseUrl(String deeplink) {
    throw UnimplementedError('extractSsoBaseUrl() has not been implemented.');
  }

  /// Returns launch deeplink if the app was opened via seamless SSO (Android: activity intent).
  Future<String?> getLaunchSeamlessDeeplink() {
    throw UnimplementedError('getLaunchSeamlessDeeplink() has not been implemented.');
  }

  /// Updates ELK user id after login ([userId] in Sber settings).
  Future<void> setUserId(String userId) {
    throw UnimplementedError('setUserId() has not been implemented.');
  }
}
