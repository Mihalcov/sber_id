import 'package:flutter/services.dart';

/// Thrown when [SBerId.instance.initialize] or other non-auth calls fail.
class SBerIdException implements Exception {
  final String code;
  final String message;

  const SBerIdException(this.code, this.message);

  factory SBerIdException.fromPlatformException(PlatformException e) {
    return SBerIdException(
      e.code.isNotEmpty ? e.code : 'UNKNOWN',
      e.message ?? 'Sber ID error',
    );
  }

  @override
  String toString() => 'SBerIdException($code): $message';
}
