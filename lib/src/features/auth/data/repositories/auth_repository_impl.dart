import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStorage = tokenStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSession?> restoreSession() async {
    final storedSession = await _tokenStorage.read();
    if (storedSession == null) {
      return null;
    }

    if (!storedSession.isAccessTokenExpired()) {
      return storedSession;
    }

    try {
      final refreshedSession = await refresh(
        accessToken: storedSession.token,
        refreshToken: storedSession.refreshToken,
      );
      return refreshedSession;
    } catch (_) {
      await _tokenStorage.clear();
      return null;
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await _remoteDataSource.login(
      email: email,
      password: password,
    );
    await _tokenStorage.save(session);
    return session;
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await _remoteDataSource.register(
      name: name,
      email: email,
      password: password,
    );
    await _tokenStorage.save(session);
    return session;
  }

  @override
  Future<AuthSession> refresh({
    required String accessToken,
    required String refreshToken,
  }) async {
    final session = await _remoteDataSource.refresh(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _tokenStorage.save(session);
    return session;
  }

  @override
  Future<void> logout() {
    return _tokenStorage.clear();
  }
}
