class AuthSession {
  const AuthSession({
    required this.issuer,
    required this.issuedAt,
    required this.expiresAt,
    required this.subject,
    required this.token,
    required this.refreshToken,
  });

  final String issuer;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String subject;
  final String token;
  final String refreshToken;

  bool isAccessTokenExpired({Duration skew = const Duration(seconds: 30)}) {
    return expiresAt.toUtc().isBefore(DateTime.now().toUtc().add(skew));
  }
}
