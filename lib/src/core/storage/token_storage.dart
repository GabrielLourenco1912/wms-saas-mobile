import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/entities/auth_session.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage(const FlutterSecureStorage());
});

abstract class TokenStorage {
  Future<AuthSession?> read();

  Future<void> save(AuthSession session);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage(this._storage);

  static const _issuerKey = 'auth.issuer';
  static const _issuedAtKey = 'auth.issued_at';
  static const _expiresAtKey = 'auth.expires_at';
  static const _subjectKey = 'auth.subject';
  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final values = await _storage.readAll();
    final accessToken = values[_accessTokenKey];
    final refreshToken = values[_refreshTokenKey];
    final subject = values[_subjectKey];
    final expiresAt = DateTime.tryParse(values[_expiresAtKey] ?? '');
    final issuedAt = DateTime.tryParse(values[_issuedAtKey] ?? '');

    if (accessToken == null ||
        refreshToken == null ||
        subject == null ||
        expiresAt == null ||
        issuedAt == null) {
      return null;
    }

    return AuthSession(
      issuer: values[_issuerKey] ?? '',
      issuedAt: issuedAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      subject: subject,
      token: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: _issuerKey, value: session.issuer);
    await _storage.write(
      key: _issuedAtKey,
      value: session.issuedAt.toUtc().toIso8601String(),
    );
    await _storage.write(
      key: _expiresAtKey,
      value: session.expiresAt.toUtc().toIso8601String(),
    );
    await _storage.write(key: _subjectKey, value: session.subject);
    await _storage.write(key: _accessTokenKey, value: session.token);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _issuerKey);
    await _storage.delete(key: _issuedAtKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _subjectKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
