import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wms_saas_mobile/src/core/storage/token_storage.dart';
import 'package:wms_saas_mobile/src/features/auth/application/auth_controller.dart';
import 'package:wms_saas_mobile/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:wms_saas_mobile/src/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:wms_saas_mobile/src/features/auth/presentation/pages/login_page.dart';

import 'auth_repository_test.dart' as support;

void main() {
  testWidgets(
    'login keeps unauthenticated challenge state until code confirmation',
    (tester) async {
      final remote = support.FakeAuthRemote();
      final router = buildRouter('/login');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              support.MemoryTokenStorage(),
            ),
            authRemoteDataSourceProvider.overrideWithValue(remote),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginPage)),
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'maria@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'password',
      );
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Confirme seu acesso'), findsOneWidget);
      expect(
        container.read(authControllerProvider).value?.isAuthenticated,
        isFalse,
      );
      expect(find.textContaining('m***@example.com'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('login-code')),
        '012345',
      );
      await tester.ensureVisible(find.text('Verificar e entrar'));
      await tester.tap(find.text('Verificar e entrar'));
      await tester.pumpAndSettle();
      expect(remote.lastCode, '012345');
      expect(
        container.read(authControllerProvider).value?.can('PICKING_EXECUTE'),
        isTrue,
      );
      expect(find.text('Operação autenticada'), findsOneWidget);
      router.dispose();
    },
  );

  testWidgets(
    'password recovery validates confirmation and resets with leading-zero code',
    (tester) async {
      final remote = support.FakeAuthRemote();
      final storage = support.MemoryTokenStorage(support.session('old'));
      final router = buildRouter('/forgot-password');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(storage),
            authRemoteDataSourceProvider.overrideWithValue(remote),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recovery-email')),
        'maria@example.com',
      );
      await tester.ensureVisible(find.text('Enviar código'));
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recovery-code')),
        '000123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recovery-password')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recovery-confirmation')),
        'different-password',
      );
      await tester.ensureVisible(find.text('Redefinir senha'));
      await tester.tap(find.text('Redefinir senha'));
      await tester.pumpAndSettle();
      expect(find.text('As senhas precisam ser iguais.'), findsOneWidget);
      expect(remote.lastResetCode, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('recovery-confirmation')),
        'new-password',
      );
      await tester.ensureVisible(find.text('Redefinir senha'));
      await tester.tap(find.text('Redefinir senha'));
      await tester.pumpAndSettle();
      expect(find.text('Senha redefinida'), findsOneWidget);
      expect(remote.lastResetCode, '000123');
      expect(remote.lastNewPassword, 'new-password');
      expect(storage.value, isNull);
      router.dispose();
    },
  );
}

GoRouter buildRouter(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, _) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (_, _) => const Scaffold(body: Text('Operação autenticada')),
    ),
  ],
);
