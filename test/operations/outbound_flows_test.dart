import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/features/operations/application/operation_command.dart';
import 'package:wms_saas_mobile/src/features/operations/data/warehouse_repository.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/outbound/operation_flow_widgets.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/outbound/picking_detail_page.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/outbound/shipment_detail_page.dart';

void main() {
  group('Quantidades operacionais', () {
    test('aceita vírgula, seis casas e zero somente no fluxo permitido', () {
      expect(validateOperationQuantity('12,123456'), isNull);
      expect(operationQuantity('12,123456'), 12.123456);
      expect(validateOperationQuantity('0'), isNotNull);
      expect(validateOperationQuantity('0', allowZero: true), isNull);
      expect(validateOperationQuantity('0.000001'), isNull);
    });

    test('rejeita perda de precisão e formatos fora do contrato', () {
      for (final value in [
        '999999999999.999999',
        '1.1234567',
        '1000000000000',
        '-1',
        '1e3',
        'NaN',
        '',
      ]) {
        expect(validateOperationQuantity(value), isNotNull, reason: value);
      }
    });
  });

  testWidgets(
    'falta zero exige leituras reais e envia JSON sem destino fictício',
    (tester) async {
      final commands = _RecordingCommands();
      await _openPage(
        tester,
        commands,
        const PickingCollectionPage(
          task: {'id': 'task-1', 'targetQuantity': 10},
          shortage: true,
        ),
      );
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      await _tapSubmit(tester, 'Registrar falta e realocar');
      expect(commands.calls, isEmpty);
      await _fill(tester, 'Posição de origem lida', 'A-01');
      await _fill(tester, 'LPN de origem lido', 'LPN-01');
      await _fill(tester, 'SKU ou barcode do produto lido', 'SKU-01');
      await _fill(tester, 'Quantidade física em unidade base', '0');
      await _fill(tester, 'Motivo da falta', 'Não localizado na posição');
      expect(find.text('Doca de expedição de destino'), findsNothing);
      await _tapSubmit(tester, 'Registrar falta e realocar');
      expect(commands.calls, hasLength(1));
      final call = commands.calls.single;
      expect(call.path, '/api/picking-tasks/task-1/divergences');
      expect(call.keyInBody, isTrue);
      expect(call.body, {
        'actualQuantity': 0,
        'sourceLpnCode': 'LPN-01',
        'sourcePositionCode': 'A-01',
        'productCode': 'SKU-01',
        'reason': 'Não localizado na posição',
      });
    },
  );

  testWidgets('falta com coleta exige doca e códigos de destino', (
    tester,
  ) async {
    final commands = _RecordingCommands();
    await _openPage(
      tester,
      commands,
      const PickingCollectionPage(
        task: {'id': 'task-1', 'targetQuantity': 10},
        shortage: true,
      ),
    );
    await _fill(tester, 'Quantidade física em unidade base', '1');
    expect(find.text('Doca de expedição de destino'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Código da doca lido'),
      findsOneWidget,
    );
    await _tapSubmit(tester, 'Registrar falta e realocar');
    expect(commands.calls, isEmpty);
  });

  testWidgets('coleta normal rejeita quantidade diferente do alvo vigente', (
    tester,
  ) async {
    final commands = _RecordingCommands();
    await _openPage(
      tester,
      commands,
      const PickingCollectionPage(task: {'id': 'task-1', 'targetQuantity': 10}),
    );
    await _fill(tester, 'Quantidade física em unidade base', '9');
    await _tapSubmit(tester, 'Confirmar coleta');
    expect(find.textContaining('Informe o alvo vigente;'), findsOneWidget);
    expect(commands.calls, isEmpty);
  });

  testWidgets(
    'conferência de expedição envia apenas códigos lidos e chave no JSON',
    (tester) async {
      final commands = _RecordingCommands();
      await _openPage(
        tester,
        commands,
        const ShipmentScanPage(shipment: {'id': 'shipment-1'}),
      );
      await _tapSubmit(tester, 'Confirmar LPN lido');
      expect(commands.calls, isEmpty);
      await _fill(tester, 'LPN lido', 'LPN-SAIDA');
      await _fill(tester, 'Código da doca lido', 'DOCA-EXP-01');
      await _tapSubmit(tester, 'Confirmar LPN lido');
      expect(commands.calls.single.path, '/api/shipments/shipment-1/confirm');
      expect(commands.calls.single.keyInBody, isTrue);
      expect(commands.calls.single.body, {
        'dockPositionCode': 'DOCA-EXP-01',
        'lpnCode': 'LPN-SAIDA',
      });
    },
  );
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

Future<void> _tapSubmit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _CommandCall {
  const _CommandCall(this.path, this.body, this.keyInBody);
  final String path;
  final JsonMap? body;
  final bool keyInBody;
}

class _RecordingCommands extends OperationCommandRunner {
  _RecordingCommands() : super(Dio());
  final calls = <_CommandCall>[];

  @override
  Future<JsonMap> run(
    String path, {
    JsonMap? body,
    bool keyInBody = false,
    String method = 'POST',
  }) async {
    calls.add(_CommandCall(path, body, keyInBody));
    return {'id': 'confirmed', 'unallocatedQuantity': 10};
  }
}
