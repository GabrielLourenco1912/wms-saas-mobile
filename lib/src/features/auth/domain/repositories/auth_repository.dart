import '../entities/auth_session.dart';

abstract class AuthRepository {
  int get sessionRevision;
  Future<AuthSession?> restoreSession();
  Future<AuthChallenge> login({
    required String email,
    required String password,
  });
  Future<AuthSession> verifyChallenge({
    required String challengeId,
    required String code,
  });
  Future<AuthChallenge> forgotPassword(String email);
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  });
  Future<AuthSession> refresh({
    required String accessToken,
    required String refreshToken,
  });
  Future<AppUser> currentUser();
  Future<void> logout();
  Future<void> clearSession();
}
