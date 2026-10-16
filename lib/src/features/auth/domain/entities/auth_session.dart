class AuthSession {
  const AuthSession({
    required this.issuer,
    required this.issuedAt,
    required this.expiresAt,
    required this.subject,
    required this.token,
    required this.refreshToken,
    this.refreshTokenExpiresAt,
    this.user,
  });

  final String issuer;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String subject;
  final String token;
  final String refreshToken;
  final DateTime? refreshTokenExpiresAt;
  final AppUser? user;

  AuthSession withUser(AppUser user) => AuthSession(
    issuer: issuer,
    issuedAt: issuedAt,
    expiresAt: expiresAt,
    subject: subject,
    token: token,
    refreshToken: refreshToken,
    refreshTokenExpiresAt: refreshTokenExpiresAt,
    user: user,
  );

  bool get canRefresh =>
      refreshToken.isNotEmpty &&
      (refreshTokenExpiresAt == null ||
          refreshTokenExpiresAt!.toUtc().isAfter(DateTime.now().toUtc()));

  bool isAccessTokenExpired({Duration skew = const Duration(seconds: 30)}) =>
      !expiresAt.toUtc().isAfter(DateTime.now().toUtc().add(skew));
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.profileCode,
    required this.profileActive,
    required this.permissions,
  });

  final String id;
  final String name;
  final String email;
  final String status;
  final String profileCode;
  final bool profileActive;
  final Set<String> permissions;

  bool can(String permission) =>
      status == 'ACTIVE' && profileActive && permissions.contains(permission);

  factory AppUser.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value! as Map);
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      status: json['status'] as String,
      profileCode: json['profileCode'] as String,
      profileActive: json['profileActive'] == true,
      permissions: Set<String>.unmodifiable(
        (json['permissions'] as List? ?? const []).cast<String>(),
      ),
    );
  }
}

class AuthChallenge {
  const AuthChallenge({
    required this.id,
    required this.purpose,
    required this.maskedEmail,
    required this.expiresAt,
    required this.maxAttempts,
  });

  final String id;
  final String purpose;
  final String maskedEmail;
  final DateTime expiresAt;
  final int maxAttempts;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  factory AuthChallenge.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value! as Map);
    return AuthChallenge(
      id: json['challengeId'] as String,
      purpose: json['purpose'] as String,
      maskedEmail: json['maskedEmail'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
      maxAttempts: json['maxAttempts'] as int,
    );
  }
}
