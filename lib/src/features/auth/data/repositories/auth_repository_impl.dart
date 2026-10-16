import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return RemoteAuthRepository(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  );
});

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;
  Future<AuthSession>? _refreshFuture;
  int _generation = 0;

  @override
  int get sessionRevision => _generation;

  @override
  Future<AuthSession?> restoreSession() async {
    final generation = _generation;
    var session = await _storage.read();
    if (session == null) return null;
    if (!session.canRefresh) {
      await clearSession();
      return null;
    }
    try {
      if (session.isAccessTokenExpired()) {
        session = await refresh(
          accessToken: session.token,
          refreshToken: session.refreshToken,
        );
      }
      final user = await _loadUser(session);
      final latest = await _storage.read();
      if (generation != _generation || latest == null) return null;
      return latest.withUser(user);
    } on ApiException catch (error) {
      if (_invalidSession(error)) {
        if (generation == _generation) await clearSession();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthChallenge> login({
    required String email,
    required String password,
  }) => _remote.login(email: email, password: password);

  @override
  Future<AuthSession> verifyChallenge({
    required String challengeId,
    required String code,
  }) async {
    final generation = ++_generation;
    final session = await _remote.verifyChallenge(
      challengeId: challengeId,
      code: code,
    );
    if (generation != _generation) {
      throw const ApiException(message: 'A autenticação foi cancelada.');
    }
    await _storage.save(session);
    final user = await _loadUser(session);
    if (generation != _generation) {
      throw const ApiException(message: 'A autenticação foi cancelada.');
    }
    return (await _storage.read() ?? session).withUser(user);
  }

  @override
  Future<AuthChallenge> forgotPassword(String email) =>
      _remote.forgotPassword(email);

  @override
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  }) async {
    await _remote.resetPassword(
      challengeId: challengeId,
      code: code,
      newPassword: newPassword,
    );
    await clearSession();
  }

  @override
  Future<AuthSession> refresh({
    required String accessToken,
    required String refreshToken,
  }) {
    final pending = _refreshFuture;
    if (pending != null) return pending;
    final generation = _generation;
    final refresh = _rotate(accessToken, refreshToken, generation);
    _refreshFuture = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshFuture, refresh)) _refreshFuture = null;
    });
  }

  Future<AuthSession> _rotate(
    String accessToken,
    String refreshToken,
    int generation,
  ) async {
    final latest = await _storage.read();
    if (latest == null || generation != _generation) {
      throw const ApiException(
        message: 'Sua sessão terminou. Entre novamente.',
        statusCode: 401,
      );
    }
    // A delayed 401 may refer to the token preceding a completed rotation.
    if (latest.token != accessToken &&
        !latest.isAccessTokenExpired(skew: Duration.zero)) {
      return latest;
    }
    if (!latest.canRefresh) {
      await clearSession();
      throw const ApiException(
        message: 'Sua sessão expirou. Entre novamente.',
        statusCode: 401,
      );
    }
    try {
      final rotated = await _remote.refresh(refreshToken: latest.refreshToken);
      if (generation != _generation) {
        try {
          await _remote.logout(rotated.refreshToken);
        } catch (_) {
          /* Local session is already gone. */
        }
        throw const ApiException(
          message: 'Sua sessão terminou. Entre novamente.',
          statusCode: 401,
        );
      }
      await _storage.save(rotated);
      if (generation != _generation) {
        final current = await _storage.read();
        if (current?.token == rotated.token) await _storage.clear();
        throw const ApiException(
          message: 'Sua sessão terminou. Entre novamente.',
          statusCode: 401,
        );
      }
      return rotated;
    } on ApiException catch (error) {
      if (_invalidSession(error) && generation == _generation) {
        await clearSession();
      }
      rethrow;
    }
  }

  Future<AppUser> _loadUser(AuthSession session) async {
    try {
      return await _remote.currentUser(session.token);
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      final updated = await refresh(
        accessToken: session.token,
        refreshToken: session.refreshToken,
      );
      return _remote.currentUser(updated.token);
    }
  }

  @override
  Future<AppUser> currentUser() async {
    final session = await _storage.read();
    if (session == null) {
      throw const ApiException(
        message: 'Entre novamente para acessar seu perfil.',
        statusCode: 401,
      );
    }
    return _loadUser(session);
  }

  @override
  Future<void> logout() async {
    final session = await _storage.read();
    await clearSession();
    if (session != null) await _remote.logout(session.refreshToken);
  }

  @override
  Future<void> clearSession() async {
    _generation++;
    await _storage.clear();
  }

  static bool _invalidSession(ApiException error) =>
      error.statusCode == 400 ||
      error.statusCode == 401 ||
      error.statusCode == 403;
}
