import 'package:flutter/services.dart';

import 'sber_id_error_code.dart';

class SBerIdAuthResponse {
  final bool isSuccess;
  final String? authCode;
  final String? state;
  final String? nonce;
  final String? codeVerifier;
  final String? error;
  final String? errorCode;

  SBerIdAuthResponse({
    required this.isSuccess,
    this.authCode,
    this.state,
    this.nonce,
    this.codeVerifier,
    this.error,
    this.errorCode,
  });

  /// User dismissed web/Safari or closed flow without completing login.
  bool get isCancelled =>
      errorCode == SBerIdErrorCode.authCancelled ||
      errorCode == SBerIdErrorCode.loginSuperseded;

  bool get hasAuthCode => authCode != null && authCode!.isNotEmpty;

  factory SBerIdAuthResponse.fromMap(Map<String, dynamic> map) {
    return SBerIdAuthResponse(
      isSuccess: map['isSuccess'] == true,
      authCode: map['authCode'] as String?,
      state: map['state'] as String?,
      nonce: map['nonce'] as String?,
      codeVerifier: map['codeVerifier'] as String?,
      error: map['error'] as String?,
      errorCode: map['errorCode'] as String?,
    );
  }

  factory SBerIdAuthResponse.error(
    String error, {
    String? code,
  }) {
    return SBerIdAuthResponse(
      isSuccess: false,
      error: error,
      errorCode: code ?? SBerIdErrorCode.unknown,
    );
  }

  factory SBerIdAuthResponse.fromPlatformException(PlatformException e) {
    return SBerIdAuthResponse.error(
      e.message ?? 'Sber ID authentication failed',
      code: e.code.isNotEmpty ? e.code : SBerIdErrorCode.authError,
    );
  }

  @override
  String toString() {
    return 'SBerIdAuthResponse(isSuccess: $isSuccess, errorCode: $errorCode, error: $error)';
  }
}
