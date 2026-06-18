import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  bool get isAuthenticated => session != null;
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final session = await ref.read(authRepositoryProvider).restoreSession();
    return session == null
        ? const AuthState.unauthenticated()
        : AuthState.authenticated(session);
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      return AuthState.authenticated(session);
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: password);
      return AuthState.authenticated(session);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(AuthState.unauthenticated());
  }

  void clearTransientError() {
    if (!state.hasError) {
      return;
    }

    state = AsyncValue.data(state.value ?? const AuthState.unauthenticated());
  }
}
