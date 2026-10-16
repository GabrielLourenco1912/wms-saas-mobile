import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/auth_session.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthState {
  const AuthState._({this.session});
  const AuthState.unauthenticated() : this._();
  const AuthState.authenticated(AuthSession session) : this._(session: session);

  final AuthSession? session;
  AppUser? get user => session?.user;
  bool get isAuthenticated => session != null && user != null;
  bool can(String permission) => user?.can(permission) ?? false;
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final session = await ref.read(authRepositoryProvider).restoreSession();
    return session == null
        ? const AuthState.unauthenticated()
        : AuthState.authenticated(session);
  }

  Future<AuthChallenge?> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      state = const AsyncValue.data(AuthState.unauthenticated());
      return challenge;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return null;
    }
  }

  Future<void> verifyChallenge({
    required String challengeId,
    required String code,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async => AuthState.authenticated(
        await ref
            .read(authRepositoryProvider)
            .verifyChallenge(challengeId: challengeId, code: code),
      ),
    );
  }

  Future<void> reloadUser() async {
    final session = state.value?.session;
    if (session == null) return;
    try {
      final user = await ref.read(authRepositoryProvider).currentUser();
      if (identical(state.value?.session, session)) {
        state = AsyncValue.data(
          AuthState.authenticated(session.withUser(user)),
        );
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await expireSession();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    // Clear the UI immediately, even if the device cannot reach the revocation endpoint.
    state = const AsyncValue.data(AuthState.unauthenticated());
    await ref.read(authRepositoryProvider).logout();
  }

  Future<void> expireSession() async {
    state = const AsyncValue.data(AuthState.unauthenticated());
    await ref.read(authRepositoryProvider).clearSession();
  }

  void clearTransientError() {
    if (state.hasError) {
      state = const AsyncValue.data(AuthState.unauthenticated());
    }
  }
}
