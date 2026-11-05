import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sber_id_platform_interface.dart';
import 'src/models/auth_response.dart';
import 'src/models/sber_id_config.dart';
import 'src/models/sber_id_exception.dart';
import 'src/models/sber_id_login_options.dart';

class MethodChannelSBerId extends SBerIdPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('sber_id_auth');

  @override
  Future<void> initialize(SBerIdConfig config) async {
    try {
      await methodChannel.invokeMethod('initialize', config.toMap());
    } on PlatformException catch (e) {
      throw SBerIdException.fromPlatformException(e);
    } catch (e) {
      throw SBerIdException('UNKNOWN', 'Failed to initialize Sber ID: $e');
    }
  }

  @override
  Future<SBerIdAuthResponse?> login({
    SBerIdLoginOptions options = const SBerIdLoginOptions(),
  }) async {
    try {
      final result = await methodChannel.invokeMethod('startSberIDAuth', options.toMap());
      if (result == null) {
        return SBerIdAuthResponse.error('No response from native Sber ID');
      }
      return SBerIdAuthResponse.fromMap(Map<String, dynamic>.from(result as Map));
    } on PlatformException catch (e) {
      return SBerIdAuthResponse.fromPlatformException(e);
    }
  }

  @override
  Future<bool> isSBerIdInstalled() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('isSberIdInstalled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await methodChannel.invokeMethod('logout');
    } on PlatformException catch (e) {
      throw SBerIdException.fromPlatformException(e);
    } catch (_) {
      // Ignore unexpected logout errors.
    }
  }

  @override
  Future<String?> extractSsoBaseUrl(String deeplink) async {
    try {
      return await methodChannel.invokeMethod<String>('extractSsoBaseUrl', {
        'deeplink': deeplink,
      });
    } on PlatformException catch (e) {
      throw SBerIdException.fromPlatformException(e);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getLaunchSeamlessDeeplink() async {
    try {
      return await methodChannel.invokeMethod<String>('getLaunchSeamlessDeeplink');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SBerIdAuthResponse?> takePendingAuthResult() async {
    try {
      final result = await methodChannel.invokeMethod('takePendingAuthResult');
      if (result == null) return null;
      return SBerIdAuthResponse.fromMap(Map<String, dynamic>.from(result as Map));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setUserId(String userId) async {
    try {
      await methodChannel.invokeMethod('setUserId', {'userId': userId});
    } on PlatformException catch (e) {
      throw SBerIdException.fromPlatformException(e);
    }
  }
}
