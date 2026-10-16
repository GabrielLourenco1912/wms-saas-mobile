import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/operations/presentation/pages/dispatch_page.dart';
import '../../features/operations/presentation/pages/inventory_page.dart';
import '../../features/operations/presentation/pages/operations_page.dart';
import '../../features/operations/presentation/pages/picking_page.dart';
import '../../features/operations/presentation/pages/putaway_page.dart';
import '../../features/operations/presentation/pages/receiving_page.dart';
import '../../features/operations/presentation/pages/stock_audit_page.dart';
import '../../features/operations/presentation/pages/transfers_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/shell/presentation/widgets/app_shell.dart';
import 'splash_page.dart';

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  final notifier = _RouterNotifier();
  ref.listen(authControllerProvider, (_, _) => notifier.notify());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/forgot-password';
      final isSplash = path == '/splash';

      if (auth.isLoading && auth.value == null) {
        return isSplash || isAuthRoute ? null : '/splash';
      }

      final isAuthenticated = auth.value?.isAuthenticated ?? false;

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (isSplash || isAuthRoute || path == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/operations',
            builder: (context, state) => const OperationsPage(),
          ),
          GoRoute(
            path: '/operations/receiving',
            builder: (context, state) => const ReceivingPage(),
          ),
          GoRoute(
            path: '/operations/putaway',
            builder: (context, state) => const PutawayPage(),
          ),
          GoRoute(
            path: '/operations/picking',
            builder: (context, state) => const PickingPage(),
          ),
          GoRoute(
            path: '/operations/dispatch',
            builder: (context, state) => const DispatchPage(),
          ),
          GoRoute(
            path: '/operations/inventory',
            builder: (context, state) => const InventoryPage(),
          ),
          GoRoute(
            path: '/operations/stock-audit',
            builder: (context, state) => const StockAuditPage(),
          ),
          GoRoute(
            path: '/operations/transfers',
            builder: (context, state) => const TransfersPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
