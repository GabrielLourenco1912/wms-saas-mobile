import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/app/branding/brand_about_card.dart';
import 'package:wms_saas_mobile/src/app/branding/brand_tokens.dart';
import 'package:wms_saas_mobile/src/app/theme/app_theme.dart';
import 'package:wms_saas_mobile/src/features/auth/presentation/widgets/auth_page_frame.dart';

void main() {
  testWidgets('authentication remains usable at 320 px and double text size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var submitted = false;
    await tester.pumpWidget(
      _app(
        AuthPageFrame(
          title: 'Confirme seu acesso',
          subtitle: 'Informe o código enviado por e-mail.',
          footer: const Text('Sua sessão está protegida.'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Código de acesso',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => submitted = true,
                child: const Text('Confirmar acesso'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '001234');
    await tester.ensureVisible(find.text('Confirmar acesso'));
    await tester.tap(find.text('Confirmar acesso'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
    expect(controller.text, '001234');
    await tester.ensureVisible(find.text(AppBrand.authorName));
    expect(tester.takeException(), isNull);
  });

  testWidgets('about credit copies the portfolio at a large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: const [BrandAboutCard()],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sobre o WMS'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copiar link do portfólio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar link do portfólio'));
    await tester.pumpAndSettle();
    expect(copied, AppBrand.portfolio);
    expect(find.text('Link do portfólio copiado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: page!,
  ),
  home: child,
);
