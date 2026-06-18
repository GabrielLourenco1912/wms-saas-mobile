import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wms_saas_mobile/src/app/app.dart';
import 'package:wms_saas_mobile/src/core/storage/token_storage.dart';
import 'package:wms_saas_mobile/src/features/auth/domain/entities/auth_session.dart';

void main() {
  testWidgets('renders the authentication entry point', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
        ],
        child: const WmsMobileApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Entrar no WMS'), findsOneWidget);
    expect(find.text('Criar uma conta para a operação'), findsOneWidget);
  });
}

class _MemoryTokenStorage implements TokenStorage {
  AuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }
}
