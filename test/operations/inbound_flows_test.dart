import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/features/auth/application/auth_controller.dart';
import 'package:wms_saas_mobile/src/features/auth/domain/entities/auth_session.dart';
import 'package:wms_saas_mobile/src/features/operations/application/operation_command.dart';
import 'package:wms_saas_mobile/src/features/operations/data/warehouse_repository.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/putaway_page.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/receiving_page.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/stock_audit_page.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/widgets/api_operation_widgets.dart';

void main() {
  testWidgets(
    'recebimento exige leituras e envia embalagem, doca e quantidade informadas',
    (tester) async {
      final commands = _RecordingCommands();
      final repository = _WarehouseFixture();
      await _open(tester, const ReceivingPage(), commands, repository);
      await tester.tap(find.text('Documento NF-001'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Conferir item');
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller?.text ?? '', isEmpty);
      }
      await _tap(tester, 'Confirmar recebimento');
      expect(commands.calls, isEmpty);
      await _select(tester, 'Embalagem do produto', 'SKU-01 — CX × 12');
      await _select(tester, 'Doca de recebimento', 'DOCA-REC-01');
      await _fill(tester, 'Quantidade de embalagens', '2');
      await _fill(tester, 'Lote obrigatório', 'LOTE-01');
      await _fill(tester, 'Código do LPN a receber', 'LPN-01');
      await _fill(tester, 'Leitura do SKU ou barcode', 'SKU-01');
      await _fill(tester, 'Leitura da etiqueta do LPN', 'LPN-01');
      await _fill(tester, 'Leitura do código da doca', 'DOCA-REC-01');
      await _tap(tester, 'Confirmar recebimento');
      expect(commands.calls.single.path, '/api/receipts/receipt-1/confirm');
      expect(commands.calls.single.keyInBody, isFalse);
      expect(commands.calls.single.body, {
        'orderItemId': 'item-1',
        'packagingId': 'package-1',
        'quantity': 2,
        'lot': 'LOTE-01',
        'expiryDate': null,
        'lpnCode': 'LPN-01',
        'positionId': 'dock-1',
        'scannedProductCode': 'SKU-01',
        'scannedLpnCode': 'LPN-01',
        'scannedPositionCode': 'DOCA-REC-01',
      });
      expect(
        repository.lookups.where((entry) => entry.$1 == 'positions').single.$2,
        {
          'warehouseId': 'warehouse-1',
          'purpose': 'RECEBIMENTO',
          'active': 'true',
        },
      );
    },
  );

  testWidgets(
    'putaway exige quantidade integral e códigos físicos sem preenchimento automático',
    (tester) async {
      final commands = _RecordingCommands();
      await _open(tester, const PutawayPage(), commands, _WarehouseFixture());
      await tester.tap(find.text('LPN-01').first);
      await tester.pumpAndSettle();
      await _tap(tester, 'Conferir destino e concluir');
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      await _fill(tester, 'Leitura da etiqueta do LPN', 'LPN-01');
      await _fill(tester, 'Leitura da posição de destino', 'A-01');
      await _fill(tester, 'Confirme a quantidade integral', '23');
      await _tap(tester, 'Concluir armazenagem');
      expect(commands.calls, isEmpty);
      await _fill(tester, 'Confirme a quantidade integral', '24,000000');
      await _tap(tester, 'Concluir armazenagem');
      expect(
        commands.calls.single.path,
        '/api/putaway-tasks/putaway-1/complete',
      );
      expect(commands.calls.single.body, {
        'actualQuantity': 24,
        'scannedLpnCode': 'LPN-01',
        'scannedDestinationCode': 'A-01',
      });
    },
  );

  testWidgets('auditoria pode ser consultada sem permissão de estoque', (
    tester,
  ) async {
    final repository = _WarehouseFixture();
    await _open(
      tester,
      const StockAuditPage(),
      _RecordingCommands(),
      repository,
      permissions: {'AUDIT_VIEW'},
    );
    expect(find.text('Saldos de estoque'), findsNothing);
    expect(find.text('Bloqueios ativos'), findsNothing);
    await tester.tap(find.text('Livro razão'));
    await tester.pumpAndSettle();
    expect(repository.resources, ['stock-transactions']);
    expect(
      find.text(
        'Nenhum registro encontrado. Revise os filtros ou atualize a consulta.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _open(
  WidgetTester tester,
  Widget page,
  _RecordingCommands commands,
  _WarehouseFixture repository, {
  Set<String> permissions = const {
    'RECEIPT_VIEW',
    'RECEIPT_EXECUTE',
    'PUTAWAY_VIEW',
    'PUTAWAY_EXECUTE',
    'PRODUCT_VIEW',
    'WAREHOUSE_VIEW',
    'STOCK_VIEW',
  },
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _AuthenticatedController(permissions),
        ),
        warehouseRepositoryProvider.overrideWithValue(repository),
        operationCommandProvider.overrideWithValue(commands),
      ],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final button = find.widgetWithText(FilledButton, text);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String label, String option) async {
  final field = find.widgetWithText(ApiLookupField, label);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

class _AuthenticatedController extends AuthController {
  _AuthenticatedController(this.permissions);
  final Set<String> permissions;
  @override
  Future<AuthState> build() async => AuthState.authenticated(
    AuthSession(
      issuer: 'wms',
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      subject: 'operator-1',
      token: 'token',
      refreshToken: 'refresh',
      user: AppUser(
        id: 'operator-1',
        name: 'Operador',
        email: 'operator@example.test',
        status: 'ACTIVE',
        profileCode: 'OPERADOR',
        profileActive: true,
        permissions: permissions,
      ),
    ),
  );
}

class _WarehouseFixture extends WarehouseRepository {
  _WarehouseFixture() : super(Dio());
  final resources = <String>[];
  final lookups = <(String, Map<String, String>)>[];
  final _receipt = <String, dynamic>{
    'id': 'receipt-1',
    'documentNumber': 'NF-001',
    'warehouseId': 'warehouse-1',
    'partnerId': 'partner-1',
    'status': 'PENDENTE',
  };
  final _putaway = <String, dynamic>{
    'id': 'putaway-1',
    'status': 'EM_EXECUCAO',
    'lpnCode': 'LPN-01',
    'originPositionCode': 'DOCA-REC-01',
    'destinationPositionCode': 'A-01',
    'targetQuantity': 24,
    'assignedUserId': 'operator-1',
    'contents': [
      {'sku': 'SKU-01', 'productName': 'Produto', 'quantity': 24},
    ],
  };

  @override
  Future<ApiPage<JsonMap>> list(
    String resource, {
    int page = 0,
    int size = 20,
    String q = '',
    Map<String, String> filters = const {},
  }) async {
    resources.add(resource);
    final content = resource == 'receipts'
        ? [_receipt]
        : resource == 'putaway-tasks'
        ? [_putaway]
        : <JsonMap>[];
    return ApiPage(
      content: content,
      page: page,
      size: size,
      totalElements: content.length,
      totalPages: content.isEmpty ? 0 : 1,
      first: true,
      last: true,
    );
  }

  @override
  Future<JsonMap> detail(String resource, String id) async =>
      switch (resource) {
        'receipts' => {
          'receipt': _receipt,
          'items': [
            {
              'id': 'item-1',
              'productId': 'product-1',
              'sku': 'SKU-01',
              'productName': 'Produto',
              'requestedQuantity': 24,
              'fulfilledQuantity': 0,
              'remainingQuantity': 24,
            },
          ],
          'confirmations': [],
        },
        'products' => {
          'id': 'product-1',
          'lotControlled': true,
          'expiryControlled': false,
          'baseUnit': 'UN',
        },
        'putaway-tasks' => _putaway,
        _ => throw StateError('Unexpected detail $resource/$id'),
      };

  @override
  Future<ApiPage<LookupOption>> lookup(
    String resource, {
    String q = '',
    int page = 0,
    Map<String, String> filters = const {},
  }) async {
    lookups.add((resource, filters));
    final option = resource == 'product-packages'
        ? const LookupOption(id: 'package-1', label: 'SKU-01 — CX × 12')
        : const LookupOption(id: 'dock-1', label: 'DOCA-REC-01');
    return ApiPage(
      content: [option],
      page: 0,
      size: 5,
      totalElements: 1,
      totalPages: 1,
      first: true,
      last: true,
    );
  }
}

class _Call {
  const _Call(this.path, this.body, this.keyInBody);
  final String path;
  final JsonMap? body;
  final bool keyInBody;
}

class _RecordingCommands extends OperationCommandRunner {
  _RecordingCommands() : super(Dio());
  final calls = <_Call>[];
  @override
  Future<JsonMap> run(
    String path, {
    JsonMap? body,
    bool keyInBody = false,
    String method = 'POST',
  }) async {
    calls.add(_Call(path, body, keyInBody));
    return path.contains('/receipts/')
        ? {
            'confirmation': {'lpnCode': 'LPN-01'},
          }
        : {
            'id': 'putaway-1',
            'status': 'CONCLUIDA',
            'destinationPositionCode': 'A-01',
          };
  }
}
