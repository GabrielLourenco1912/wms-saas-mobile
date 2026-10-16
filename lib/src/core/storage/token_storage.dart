import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/data/models/auth_session_model.dart';

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
  static const _sessionKey = 'wms.auth.session.v2';
  static const _legacyKeys = [
    'auth.issuer',
    'auth.issued_at',
    'auth.expires_at',
    'auth.subject',
    'auth.access_token',
    'auth.refresh_token',
  ];
  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return AuthSessionModel.fromJson(jsonDecode(raw));
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) => _storage.write(
    key: _sessionKey,
    value: jsonEncode({
      'issuer': session.issuer,
      'issuedAt': session.issuedAt.toUtc().toIso8601String(),
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
      'subject': session.subject,
      'token': session.token,
      'refreshToken': session.refreshToken,
      'refreshTokenExpiresAt': session.refreshTokenExpiresAt
          ?.toUtc()
          .toIso8601String(),
    }),
  );

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }
}
