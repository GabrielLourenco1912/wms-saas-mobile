import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/core/errors/api_exception.dart';
import 'package:wms_saas_mobile/src/core/storage/token_storage.dart';
import 'package:wms_saas_mobile/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:wms_saas_mobile/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:wms_saas_mobile/src/features/auth/domain/entities/auth_session.dart';

void main() {
  test(
    'concurrent refreshes rotate once and a delayed 401 reuses new tokens',
    () async {
      final storage = MemoryTokenStorage(session('old'));
      final remote = FakeAuthRemote();
      final gate = Completer<AuthSession>();
      remote.onRefresh = (_) => gate.future;
      final repository = RemoteAuthRepository(remote, storage);
      final first = repository.refresh(
        accessToken: 'old',
        refreshToken: 'refresh-old',
      );
      final second = repository.refresh(
        accessToken: 'old',
        refreshToken: 'refresh-old',
      );
      await Future<void>.delayed(Duration.zero);
      expect(remote.refreshCalls, 1);
      gate.complete(session('new'));
      expect((await first).token, 'new');
      expect((await second).token, 'new');
      expect(
        (await repository.refresh(
          accessToken: 'old',
          refreshToken: 'refresh-old',
        )).token,
        'new',
      );
      expect(remote.refreshCalls, 1);
      expect(storage.value?.refreshToken, 'refresh-new');
    },
  );

  test(
    'restoration refreshes expired access and loads current permissions',
    () async {
      final storage = MemoryTokenStorage(session('old', expired: true));
      final remote = FakeAuthRemote();
      final repository = RemoteAuthRepository(remote, storage);
      final restored = await repository.restoreSession();
      expect(remote.refreshCalls, 1);
      expect(remote.userTokens, ['new']);
      expect(restored?.token, 'new');
      expect(restored?.user?.name, 'Maria');
      expect(restored?.user?.can('PICKING_EXECUTE'), isTrue);
      expect(restored?.user?.can('USER_CREATE'), isFalse);
    },
  );

  test(
    'restoration retains credentials when the network is unavailable',
    () async {
      final storage = MemoryTokenStorage(session('old'));
      final remote = FakeAuthRemote()
        ..userError = const ApiException(message: 'Sem conexão.');
      final repository = RemoteAuthRepository(remote, storage);
      await expectLater(
        repository.restoreSession(),
        throwsA(isA<ApiException>()),
      );
      expect(storage.value?.token, 'old');
    },
  );

  test('a rejected refresh clears the stored session', () async {
    final storage = MemoryTokenStorage(session('old', expired: true));
    final remote = FakeAuthRemote()
      ..onRefresh = (_) async =>
          throw const ApiException(message: 'Revogado.', statusCode: 401);
    final repository = RemoteAuthRepository(remote, storage);
    expect(await repository.restoreSession(), isNull);
    expect(storage.value, isNull);
  });

  test(
    'logout clears credentials even when remote revocation is offline',
    () async {
      final storage = MemoryTokenStorage(session('old'));
      final remote = FakeAuthRemote()
        ..logoutError = const ApiException(message: 'Sem conexão.');
      final repository = RemoteAuthRepository(remote, storage);
      await expectLater(repository.logout(), throwsA(isA<ApiException>()));
      expect(storage.value, isNull);
      expect(remote.revokedTokens, ['refresh-old']);
    },
  );

  test('an in-flight refresh cannot recreate a session after logout', () async {
    final storage = MemoryTokenStorage(session('old'));
    final remote = FakeAuthRemote();
    final gate = Completer<AuthSession>();
    remote.onRefresh = (_) => gate.future;
    final repository = RemoteAuthRepository(remote, storage);
    final refresh = repository.refresh(
      accessToken: 'old',
      refreshToken: 'refresh-old',
    );
    final assertion = expectLater(refresh, throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    await repository.logout();
    gate.complete(session('new'));
    await assertion;
    expect(storage.value, isNull);
    expect(remote.revokedTokens, containsAll(['refresh-old', 'refresh-new']));
  });

  test(
    'challenge confirmation persists tokens and fetches identity from /me',
    () async {
      final storage = MemoryTokenStorage();
      final remote = FakeAuthRemote();
      final repository = RemoteAuthRepository(remote, storage);
      final result = await repository.verifyChallenge(
        challengeId: 'challenge',
        code: '012345',
      );
      expect(result.user?.email, 'maria@example.com');
      expect(result.subject, 'user-1');
      expect(storage.value?.refreshToken, 'refresh-new');
      expect(remote.lastCode, '012345');
    },
  );

  test('an inactive profile cannot use permissions included in a response', () {
    const user = AppUser(
      id: 'user',
      name: 'Maria',
      email: 'maria@example.com',
      status: 'ACTIVE',
      profileCode: 'OPERADOR',
      profileActive: false,
      permissions: {'STOCK_VIEW'},
    );
    expect(user.can('STOCK_VIEW'), isFalse);
  });
}

AuthSession session(String token, {bool expired = false}) {
  final now = DateTime.now().toUtc();
  return AuthSession(
    issuer: 'wms',
    issuedAt: now.subtract(const Duration(minutes: 1)),
    expiresAt: now.add(Duration(minutes: expired ? -1 : 15)),
    subject: 'user-1',
    token: token,
    refreshToken: 'refresh-$token',
    refreshTokenExpiresAt: now.add(const Duration(days: 30)),
  );
}

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.value]);
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> save(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeAuthRemote implements AuthRemoteDataSource {
  int refreshCalls = 0;
  final userTokens = <String>[];
  final revokedTokens = <String>[];
  Object? userError;
  Object? logoutError;
  String? lastCode;
  String? lastResetCode;
  String? lastNewPassword;
  Future<AuthSession> Function(String token)? onRefresh;

  @override
  Future<AuthSession> refresh({required String refreshToken}) {
    refreshCalls++;
    return onRefresh?.call(refreshToken) ?? Future.value(session('new'));
  }

  @override
  Future<AppUser> currentUser(String token) async {
    userTokens.add(token);
    if (userError != null) throw userError!;
    return const AppUser(
      id: 'user-1',
      name: 'Maria',
      email: 'maria@example.com',
      status: 'ACTIVE',
      profileCode: 'OPERADOR',
      profileActive: true,
      permissions: {'PICKING_EXECUTE', 'STOCK_VIEW'},
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    revokedTokens.add(refreshToken);
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<AuthSession> verifyChallenge({
    required String challengeId,
    required String code,
  }) async {
    lastCode = code;
    return session('new');
  }

  @override
  Future<AuthChallenge> login({
    required String email,
    required String password,
  }) async => challenge();
  @override
  Future<AuthChallenge> forgotPassword(String email) async => challenge();
  @override
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  }) async {
    lastResetCode = code;
    lastNewPassword = newPassword;
  }

  AuthChallenge challenge() => AuthChallenge(
    id: 'challenge',
    purpose: 'MFA_LOGIN',
    maskedEmail: 'm***@example.com',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    maxAttempts: 5,
  );
}
