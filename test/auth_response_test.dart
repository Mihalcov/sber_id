import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sber_id/sber_id.dart';

void main() {
  test('fromMap success', () {
    final r = SBerIdAuthResponse.fromMap({
      'isSuccess': true,
      'authCode': 'code',
      'codeVerifier': 'verifier',
    });
    expect(r.isSuccess, true);
    expect(r.hasAuthCode, true);
    expect(r.isCancelled, false);
  });

  test('fromMap cancelled', () {
    final r = SBerIdAuthResponse.fromMap({
      'isSuccess': false,
      'errorCode': 'AUTH_CANCELLED',
      'error': 'cancelled',
    });
    expect(r.isCancelled, true);
    expect(r.errorCode, SBerIdErrorCode.authCancelled);
  });

  test('fromPlatformException maps code', () {
    final r = SBerIdAuthResponse.fromPlatformException(
      PlatformException(code: 'NOT_INITIALIZED', message: 'init first'),
    );
    expect(r.isSuccess, false);
    expect(r.errorCode, 'NOT_INITIALIZED');
  });
}
