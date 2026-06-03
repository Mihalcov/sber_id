/// Configuration passed to native Sber ID SDK on initialize.
class SBerIdConfig {
  final String clientId;
  final String redirectUri;
  final String partnerName;
  final List<String> scopes;

  /// Test stand: `prom` (default) or `cloud_ift`.
  final String stand;

  /// Partner user id token (optional, can be set after login).
  final String? userId;

  /// ELK partner profile URL (Android: SIDELK.setProfileUrl).
  final String? partnerProfileUrl;

  const SBerIdConfig({
    required this.clientId,
    required this.redirectUri,
    required this.partnerName,
    this.scopes = const ['openid', 'name', 'email'],
    this.stand = 'prom',
    this.userId,
    this.partnerProfileUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'redirectUri': redirectUri,
      'partnerName': partnerName,
      'scopes': scopes,
      'stand': stand,
      if (userId != null) 'userId': userId,
      if (partnerProfileUrl != null) 'partnerProfileUrl': partnerProfileUrl,
    };
  }
}
