import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wms_saas_mobile/main.dart' as application;
import 'package:wms_saas_mobile/src/app/app.dart';
import 'package:wms_saas_mobile/src/app/router/app_router.dart';
import 'package:wms_saas_mobile/src/core/diagnostics/feedback_probe.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/widgets/api_operation_widgets.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final driver = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'HOMOL_DRIVER_URL',
        defaultValue: 'http://10.0.2.2:8777',
      ),
      headers: {
        'Authorization':
            'Bearer ${const String.fromEnvironment('HOMOL_DRIVER_TOKEN')}',
      },
      receiveTimeout: const Duration(minutes: 2),
    ),
  );
  Future<Map<String, dynamic>> phase(String path) async =>
      Map<String, dynamic>.from((await driver.get<Object?>(path)).data as Map);

  testWidgets(
    'web e Flutter executam entrada, putaway, onda, picking e despacho com API/MySQL reais',
    (tester) async {
      final config = await phase('/config');
      await const FlutterSecureStorage().deleteAll();
      application.main();
      await until(tester, find.byKey(const ValueKey('login-email')));
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        config['operatorEmail'] as String,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        config['operatorPassword'] as String,
      );
      await tap(tester, 'Continuar');
      await until(tester, find.byKey(const ValueKey('login-code')));
      final code = await phase('/otp');
      await tester.enterText(
        find.byKey(const ValueKey('login-code')),
        code['code'] as String,
      );
      await tap(tester, 'Verificar e entrar');
      await until(tester, find.text('Recebimento'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WmsMobileApp)),
      );
      final router = container.read(appRouterProvider);
      await binding.convertFlutterSurfaceToImage();

      router.go('/operations/receiving');
      await until(
        tester,
        find.widgetWithText(TextField, 'Pesquisar documento ou ID'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Pesquisar documento ou ID'),
        config['receiptDocument'] as String,
      );
      await tap(tester, 'Documento ${config['receiptDocument']}');
      await tap(tester, 'Conferir item');
      await select(
        tester,
        'Embalagem do produto',
        config['product']['sku'] as String,
      );
      await select(tester, 'Doca de recebimento', 'H-REC');
      await fill(tester, 'Quantidade de embalagens', '20');
      await fill(
        tester,
        'Código do LPN a receber',
        config['inboundLpn'] as String,
      );
      await fill(
        tester,
        'Leitura do SKU ou barcode',
        config['product']['sku'] as String,
      );
      await fill(
        tester,
        'Leitura da etiqueta do LPN',
        config['inboundLpn'] as String,
      );
      await fill(tester, 'Leitura do código da doca', 'H-REC');
      FeedbackProbe.reset();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tap(tester, 'Confirmar recebimento');
      await until(tester, find.textContaining('Conferência registrada.'));
      await binding.takeScreenshot('05-mobile-receipt');
      final received = await phase('/phase/received');

      router.go('/operations/putaway');
      await until(
        tester,
        find.widgetWithText(TextField, 'Pesquisar tarefa, pedido ou ID do LPN'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Pesquisar tarefa, pedido ou ID do LPN'),
        received['putaway']['lpnId'] as String,
      );
      await tap(tester, config['inboundLpn'] as String);
      await tap(tester, 'Iniciar e assumir tarefa');
      await tap(tester, 'Conferir destino e concluir');
      await fill(tester, 'Confirme a quantidade integral', '20');
      await fill(
        tester,
        'Leitura da etiqueta do LPN',
        config['inboundLpn'] as String,
      );
      await fill(
        tester,
        'Leitura da posição de destino',
        received['putaway']['destinationPositionCode'] as String,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tap(tester, 'Concluir armazenagem');
      await until(tester, find.textContaining('LPN armazenado em'));
      await binding.takeScreenshot('06-mobile-putaway');
      final planned = await phase('/phase/putaway');

      router.go('/operations/picking');
      await until(
        tester,
        find.widgetWithText(TextField, 'Pesquisar tarefa, pedido ou LPN'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Pesquisar tarefa, pedido ou LPN'),
        planned['order']['id'] as String,
      );
      await tap(tester, "${config['product']['sku']} ·", contains: true);
      await tap(tester, 'Iniciar e assumir tarefa');
      await tap(tester, 'Confirmar início');
      await tap(tester, 'Conferir e concluir coleta');
      final task = planned['wave']['tasks'][0] as Map;
      await fill(
        tester,
        'Posição de origem lida',
        task['originPositionCode'] as String,
      );
      await fill(tester, 'LPN de origem lido', task['sourceLpnCode'] as String);
      await fill(
        tester,
        'SKU ou barcode do produto lido',
        config['product']['sku'] as String,
      );
      await fill(tester, 'Quantidade física em unidade base', '8');
      await select(tester, 'Doca de expedição de destino', 'H-EXP');
      await fill(tester, 'Código da doca lido', 'H-EXP');
      await fill(
        tester,
        'LPN de destino lido',
        config['outboundLpn'] as String,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tap(tester, 'Confirmar coleta');
      await until(
        tester,
        find.textContaining('Operação confirmada pelo servidor.'),
      );
      await binding.takeScreenshot('07-mobile-picking');
      await phase('/phase/picked');

      router.go('/operations/dispatch');
      await until(tester, find.byTooltip('Preparar carga'));
      await tester.tap(find.byTooltip('Preparar carga'));
      await select(
        tester,
        'Pedido de saída',
        config['orderDocument'] as String,
      );
      await select(tester, 'Doca de expedição', 'H-EXP');
      await select(
        tester,
        'Adicionar LPN à carga',
        config['outboundLpn'] as String,
      );
      await tap(tester, 'Criar carga para conferência');
      final prepared = await phase('/phase/shipment');
      await tap(tester, 'Carga ${prepared['shipment']['id']}');
      await tap(tester, 'Conferir um LPN');
      await fill(tester, 'LPN lido', config['outboundLpn'] as String);
      await fill(tester, 'Código da doca lido', 'H-EXP');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tap(tester, 'Confirmar LPN lido');
      await tap(tester, 'Despachar carga');
      await fill(tester, 'Código da doca lido', 'H-EXP');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tap(tester, 'Confirmar despacho físico');
      await until(tester, find.text('Despachada'));
      await binding.takeScreenshot('08-mobile-dispatched');
      final result = await phase('/phase/finish');
      await tester.pump();
      binding.reportData = {
        ...?binding.reportData,
        'runId': config['runId'],
        'cycle': 'passed',
        'serverScenarios': result['passed'],
        'feedbackSamples': List<Map<String, Object>>.from(
          FeedbackProbe.samples,
        ),
        'measurementScope':
            'Android emulator; keyboard input; debug build. Physical camera/device evaluation remains manual.',
      };
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

Future<void> until(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 150));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Elemento não encontrado: $finder');
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty &&
      find.byType(ListView).evaluate().isNotEmpty) {
    final viewport = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(viewport).position;
    position.jumpTo(position.minScrollExtent);
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await Scrollable.ensureVisible(
        tester.element(finder.first),
        alignment: 0.45,
      );
      await tester.pump(const Duration(milliseconds: 150));
      if (finder.hitTestable().evaluate().isNotEmpty) return;
    }
    if (attempt > 4 &&
        attempt % 3 == 0 &&
        find.byType(ListView).evaluate().isNotEmpty) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    }
  }
  await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(
    'failure-field',
  );
  debugPrint(
    'HOMOL visible texts: ${tester.allWidgets.whereType<Text>().map((widget) => widget.data).whereType<String>().join(" | ")}',
  );
  throw TestFailure(
    'Campo/controle não disponível após carregar e percorrer a tela: $finder',
  );
}

Future<void> tap(
  WidgetTester tester,
  String text, {
  bool contains = false,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 200));
  final finder = contains ? find.textContaining(text) : find.text(text);
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 150));
    if (attempt > 4 && find.byType(ListView).evaluate().isNotEmpty) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    }
  }
  await visible(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final finder = find.widgetWithText(TextFormField, label);
  await visible(tester, finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> select(WidgetTester tester, String label, String query) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 200));
  final finder = find.byWidgetPredicate(
    (widget) => widget is ApiLookupField && widget.label == label,
  );
  await visible(tester, finder);
  for (
    var attempt = 0;
    attempt < 100 && !tester.widget<ApiLookupField>(finder.first).enabled;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    tester.widget<ApiLookupField>(finder.first).enabled,
    isTrue,
    reason: 'Seletor $label precisa estar habilitado',
  );
  await tester.tap(finder.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  final search = find.widgetWithText(TextField, 'Pesquisar opções');
  await until(tester, search);
  await tester.enterText(search, query);
  final option = find.descendant(
    of: find.byType(ListTile),
    matching: find.textContaining(query),
  );
  await until(tester, option);
  // Long document labels can wrap underneath the keyboard on a 320 px device.
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await Scrollable.ensureVisible(tester.element(option.first), alignment: 0.3);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  expect(option.first.hitTestable(), findsOneWidget);
  await tester.tap(option.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  expect(find.byTooltip('Fechar seleção'), findsNothing);
}
