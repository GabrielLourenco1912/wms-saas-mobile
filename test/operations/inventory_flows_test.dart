import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/features/auth/application/auth_controller.dart';
import 'package:wms_saas_mobile/src/features/auth/domain/entities/auth_session.dart';
import 'package:wms_saas_mobile/src/features/operations/application/operation_command.dart';
import 'package:wms_saas_mobile/src/features/operations/data/warehouse_repository.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/inventory/inventory_forms.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/inventory/inventory_detail_page.dart';

void main() {
  test('validade exige data ISO real, preservando anos bissextos', () {
    expect(validateInventoryDate('2028-02-29'), isNull);
    expect(validateInventoryDate('2026-02-29'), isNotNull);
    expect(validateInventoryDate('2026-13-01'), isNotNull);
    expect(validateInventoryDate('15/10/2026'), isNotNull);
    expect(validateInventoryDate(''), isNull);
  });

  testWidgets('contagem do snapshot permite zero sem copiar saldo ou códigos', (
    tester,
  ) async {
    final commands = _RecordingCommands();
    await _openPage(
      tester,
      commands,
      const InventoryCountPage(
        inventory: {'id': 'inventory-1'},
        item: {
          'id': 'snapshot-1',
          'sku': 'SKU-01',
          'lpnCode': 'LPN-01',
          'theoreticalQuantity': 25,
        },
      ),
    );
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.controller!.text, isEmpty);
    }
    await _submit(tester, 'Registrar contagem física');
    expect(commands.paths, isEmpty);
    await _fill(tester, 'Código físico da posição lido', 'A-01');
    await _fill(tester, 'LPN lido', 'LPN-01');
    await _fill(tester, 'SKU do produto lido', 'SKU-01');
    await _fill(tester, 'Quantidade física em unidade base', '0');
    await _submit(tester, 'Registrar contagem física');
    expect(commands.paths, ['/api/inventories/inventory-1/counts']);
    expect(commands.body, {
      'scannedPositionCode': 'A-01',
      'items': [
        {
          'inventoryItemId': 'snapshot-1',
          'lpnCode': 'LPN-01',
          'scannedProductCode': 'SKU-01',
          'countedQuantity': 0,
        },
      ],
    });
    expect(commands.keyInBody, isFalse);
  });

  testWidgets(
    'reconciliação exige justificativa e usa comando distinto da contagem',
    (tester) async {
      final commands = _RecordingCommands();
      await _openPage(
        tester,
        commands,
        const InventoryClosePage(inventory: {'id': 'inventory-1'}),
      );
      await _fill(tester, 'Código físico da posição lido', 'A-01');
      await _submit(tester, 'Aplicar ajustes e encerrar');
      expect(commands.paths, isEmpty);
      await _fill(
        tester,
        'Justificativa da reconciliação',
        'Conferência final autorizada',
      );
      await _submit(tester, 'Aplicar ajustes e encerrar');
      expect(commands.paths, ['/api/inventories/inventory-1/adjust']);
      expect(commands.body, {
        'scannedPositionCode': 'A-01',
        'reason': 'Conferência final autorizada',
      });
      expect(commands.keyInBody, isFalse);
    },
  );

  testWidgets('cancelamento não envia ajustes nem quantidades', (tester) async {
    final commands = _RecordingCommands();
    await _openPage(
      tester,
      commands,
      const InventoryClosePage(inventory: {'id': 'inventory-1'}, cancel: true),
    );
    expect(find.text('Justificativa da reconciliação'), findsNothing);
    await _fill(tester, 'Código físico da posição lido', 'A-01');
    await _submit(tester, 'Confirmar cancelamento');
    expect(commands.paths, ['/api/inventories/inventory-1/cancel']);
    expect(commands.body, {'scannedPositionCode': 'A-01'});
  });

  testWidgets('operador não conta inventário de outro responsável', (
    tester,
  ) async {
    await _openInventory(tester, {
      'INVENTORY_VIEW',
      'INVENTORY_EXECUTE',
    }, counted: false);
    expect(
      find.textContaining('A contagem deve ser registrada pelo responsável'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Registrar contagem física'),
      findsNothing,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Cancelar inventário'),
      findsNothing,
    );
    expect(
      find.widgetWithText(FilledButton, 'Reconciliar e encerrar'),
      findsNothing,
    );
  });

  testWidgets(
    'gestor com permissão de ajuste reconcilia sem assumir a contagem',
    (tester) async {
      await _openInventory(tester, {
        'INVENTORY_VIEW',
        'INVENTORY_ADJUST',
      }, counted: true);
      expect(
        find.widgetWithText(OutlinedButton, 'Recontar item'),
        findsNothing,
      );
      final reconcile = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reconciliar e encerrar'),
      );
      expect(reconcile.onPressed, isNotNull);
      expect(
        find.widgetWithText(OutlinedButton, 'Cancelar inventário'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _openInventory(
  WidgetTester tester,
  Set<String> permissions, {
  required bool counted,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(
          _InventoryRepository(counted: counted),
        ),
        authControllerProvider.overrideWith(() => _InventoryAuth(permissions)),
      ],
      child: const MaterialApp(home: InventoryDetailPage(id: 'inventory-1')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPage(
  WidgetTester tester,
  _RecordingCommands commands,
  Widget page,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [operationCommandProvider.overrideWithValue(commands)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => page),
              ),
              child: const Text('Abrir teste'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir teste'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _RecordingCommands extends OperationCommandRunner {
  _RecordingCommands() : super(Dio());
  final paths = <String>[];
  JsonMap? body;
  bool? keyInBody;
  @override
  Future<JsonMap> run(
    String path, {
    JsonMap? body,
    bool keyInBody = false,
    String method = 'POST',
  }) async {
    paths.add(path);
    this.body = body;
    this.keyInBody = keyInBody;
    return {
      'inventory': {'id': 'inventory-1'},
      'items': [],
    };
  }
}

class _InventoryRepository extends WarehouseRepository {
  _InventoryRepository({required this.counted}) : super(Dio());
  final bool counted;
  @override
  Future<JsonMap> detail(String resource, String id) async => {
    'inventory': {
      'id': id,
      'status': 'EM_CONTAGEM',
      'positionId': 'position-1',
      'responsibleUserId': 'another-user',
    },
    'items': [
      {
        'id': 'snapshot-1',
        'sku': 'SKU-01',
        'lpnCode': 'LPN-01',
        'theoreticalQuantity': 25,
        'countedQuantity': counted ? 24 : null,
      },
    ],
  };
}

class _InventoryAuth extends AuthController {
  _InventoryAuth(this.permissions);
  final Set<String> permissions;
  @override
  Future<AuthState> build() async => AuthState.authenticated(
    AuthSession(
      issuer: 'test',
      issuedAt: DateTime.utc(2026),
      expiresAt: DateTime.utc(2030),
      subject: 'my-user',
      token: 'test',
      refreshToken: 'test',
      user: AppUser(
        id: 'my-user',
        name: 'Pessoa',
        email: 'test@example.com',
        status: 'ACTIVE',
        profileCode: 'CUSTOM',
        profileActive: true,
        permissions: permissions,
      ),
    ),
  );
}
