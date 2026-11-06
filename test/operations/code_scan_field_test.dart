import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/widgets/code_scan_field.dart';

void main() {
  Future<TextEditingController> mount(
    WidgetTester tester,
    CodeScanLauncher launcher, {
    bool enabled = true,
    int maxLength = 100,
    ValueChanged<String>? onChanged,
  }) async {
    final controller = TextEditingController(text: 'anterior');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeScanField(
            controller: controller,
            label: 'LPN',
            enabled: enabled,
            maxLength: maxLength,
            scanLauncher: launcher,
            onChanged: onChanged,
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets(
    'camera keeps leading zeros and updates the same input contract',
    (tester) async {
      String? changed;
      final controller = await mount(
        tester,
        (_) async => ' 000123Ab ',
        onChanged: (value) => changed = value,
      );
      await tester.tap(find.byTooltip('Ler LPN com câmera'));
      await tester.pumpAndSettle();
      expect(controller.text, '000123Ab');
      expect(changed, '000123Ab');
    },
  );

  testWidgets('cancel preserves the previous input', (tester) async {
    final controller = await mount(tester, (_) async => null);
    await tester.tap(find.byTooltip('Ler LPN com câmera'));
    await tester.pumpAndSettle();
    expect(controller.text, 'anterior');
  });

  testWidgets('disabled field cannot open a camera', (tester) async {
    var calls = 0;
    await mount(tester, (_) async {
      calls++;
      return '123';
    }, enabled: false);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    expect(calls, 0);
  });

  testWidgets(
    'concurrent taps launch once and permit a subsequent independent scan',
    (tester) async {
      var calls = 0;
      final pending = Completer<String?>();
      final controller = await mount(tester, (_) {
        calls++;
        return pending.future;
      });
      final button = tester.widget<IconButton>(find.byType(IconButton));
      button.onPressed!();
      button.onPressed!();
      expect(calls, 1);
      pending.complete('LPN-01');
      await tester.pumpAndSettle();
      expect(controller.text, 'LPN-01');
      await tester.tap(find.byTooltip('Ler LPN com câmera'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );

  for (final code in ['', '123456']) {
    testWidgets('invalid captured value is not written: "$code"', (
      tester,
    ) async {
      final controller = await mount(tester, (_) async => code, maxLength: 5);
      await tester.tap(find.byTooltip('Ler LPN com câmera'));
      await tester.pumpAndSettle();
      expect(controller.text, 'anterior');
      expect(find.textContaining('Não foi possível ler'), findsOneWidget);
    });
  }

  testWidgets('camera failure preserves input and leaves keyboard available', (
    tester,
  ) async {
    final controller = await mount(
      tester,
      (_) async => throw StateError('camera'),
    );
    await tester.tap(find.byTooltip('Ler LPN com câmera'));
    await tester.pumpAndSettle();
    expect(controller.text, 'anterior');
    await tester.enterText(find.byType(TextFormField), '00099');
    expect(controller.text, '00099');
  });
}
