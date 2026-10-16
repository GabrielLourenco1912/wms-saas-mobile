import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/app/app.dart';
import 'package:wms_saas_mobile/src/app/theme/app_theme.dart';
import 'package:wms_saas_mobile/src/core/errors/api_exception.dart';
import 'package:wms_saas_mobile/src/features/auth/application/auth_controller.dart';
import 'package:wms_saas_mobile/src/features/auth/domain/entities/auth_session.dart';
import 'package:wms_saas_mobile/src/features/operations/data/warehouse_repository.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/operations_page.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/widgets/api_operation_widgets.dart';

void main() {
  testWidgets(
    'list searches with debounce, resets page and paginates preserving query',
    (tester) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository,
        const ApiResourceListPage(
          title: 'Recebimentos',
          resource: 'receipts',
          permission: 'RECEIPT_VIEW',
        ),
      );
      expect(repository.queries.single, (0, 20, ''));
      expect(find.text('Documento 0'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'NF 123');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.queries, hasLength(1));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(repository.queries.last, (0, 20, 'NF 123'));
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      expect(repository.queries.last, (1, 20, 'NF 123'));
      await tester.enterText(find.byType(TextField), 'outro');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repository.queries.last, (0, 20, 'outro'));
    },
  );

  testWidgets('unauthorized list makes no request', (tester) async {
    final repository = _Repository();
    await _pump(
      tester,
      repository,
      const ApiResourceListPage(
        title: 'Auditoria',
        resource: 'stock-transactions',
        permission: 'AUDIT_VIEW',
      ),
      permissions: {'RECEIPT_VIEW'},
    );
    expect(repository.queries, isEmpty);
    expect(
      find.text('Seu perfil não tem acesso a esta consulta.'),
      findsOneWidget,
    );
  });

  testWidgets('query failure shows retry without a false zero result', (
    tester,
  ) async {
    final repository = _Repository()..fail = true;
    await _pump(
      tester,
      repository,
      const ApiResourceListPage(
        title: 'Recebimentos',
        resource: 'receipts',
        permission: 'RECEIPT_VIEW',
      ),
    );
    expect(find.text('Servidor indisponível.'), findsOneWidget);
    expect(find.textContaining('Nenhum registro'), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Documento 0'), findsOneWidget);
  });

  testWidgets(
    'lookup searches and paginates five labeled options, returns ID',
    (tester) async {
      final repository = _Repository();
      LookupOption? selected;
      await _pump(
        tester,
        repository,
        Scaffold(
          body: Center(
            child: ApiLookupField(
              resource: 'positions',
              label: 'Doca',
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ApiLookupField));
      await tester.pumpAndSettle();
      expect(repository.lookupQueries.single, (0, ''));
      await tester.enterText(find.byType(TextField), 'EXP');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repository.lookupQueries.last, (0, 'EXP'));
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      expect(repository.lookupQueries.last, (1, 'EXP'));
      await tester.tap(find.text('Doca legível 5'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'position-5');
      expect(selected?.label, 'Doca legível 5');
    },
  );

  testWidgets(
    'permission revocation cancels a pending search and hides existing rows',
    (tester) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository,
        const ApiResourceListPage(
          title: 'Recebimentos',
          resource: 'receipts',
          permission: 'RECEIPT_VIEW',
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ApiResourceListPage)),
      );
      await tester.enterText(find.byType(TextField), 'nova busca');
      (container.read(authControllerProvider.notifier) as _Auth).revoke();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repository.queries, hasLength(1));
      expect(find.text('Documento 0'), findsNothing);
      expect(
        find.text('Seu perfil não tem acesso a esta consulta.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('open lookup discards options after permission revocation', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(
      tester,
      repository,
      Scaffold(
        body: Center(
          child: ApiLookupField(
            resource: 'positions',
            label: 'Doca',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ApiLookupField)),
    );
    await tester.tap(find.byType(ApiLookupField));
    await tester.pumpAndSettle();
    expect(find.text('Doca legível 0'), findsOneWidget);
    (container.read(authControllerProvider.notifier) as _Auth).revoke();
    await tester.pumpAndSettle();
    expect(find.text('Doca legível 0'), findsNothing);
    expect(find.text('Seleção indisponível'), findsOneWidget);
    expect(repository.lookupQueries, hasLength(1));
  });

  testWidgets(
    'operational navigation hides modules outside the user permissions',
    (tester) async {
      await _pump(
        tester,
        _Repository(),
        const OperationsPage(),
        permissions: {'PICKING_VIEW'},
      );
      expect(find.text('Separação'), findsOneWidget);
      expect(find.text('Inventário'), findsNothing);
      expect(find.text('Recebimento'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard and list fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      _Repository(),
      const ApiResourceListPage(
        title: 'Recebimento',
        resource: 'receipts',
        permission: 'RECEIPT_VIEW',
        statuses: ['PENDENTE', 'ATENDIDO'],
      ),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated dashboard renders server totals and mobile shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screenshotDirectory = Platform.environment['WMS_SCREENSHOT_DIR'];
    if (screenshotDirectory != null) {
      await tester.runAsync(() async {
        for (final font in {
          'Roboto':
              '${Platform.environment['WMS_FONT_DIR']}/Roboto-Regular.ttf',
          'MaterialIcons':
              '${Platform.environment['WMS_FONT_DIR']}/MaterialIcons-Regular.otf',
        }.entries) {
          final file = File(font.value);
          if (file.existsSync()) {
            await (FontLoader(font.key)..addFont(
                  Future.value(ByteData.sublistView(file.readAsBytesSync())),
                ))
                .load();
          }
        }
      });
    }
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _Auth(_allPermissions)),
          warehouseRepositoryProvider.overrideWithValue(_Repository()),
        ],
        child: RepaintBoundary(key: boundaryKey, child: const WmsMobileApp()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria Operadora'), findsOneWidget);
    expect(find.text('41'), findsWidgets);
    expect(find.text('Painel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (screenshotDirectory != null) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(screenshotDirectory).createSync(recursive: true);
        File(
          '$screenshotDirectory/dashboard.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

const _allPermissions = {
  'RECEIPT_VIEW',
  'WAREHOUSE_VIEW',
  'PRODUCT_VIEW',
  'PUTAWAY_VIEW',
  'PICKING_VIEW',
  'SHIPMENT_VIEW',
  'INVENTORY_VIEW',
  'TRANSFER_VIEW',
  'STOCK_VIEW',
};
Future<void> _pump(
  WidgetTester tester,
  _Repository repository,
  Widget page, {
  Set<String> permissions = _allPermissions,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _Auth(permissions)),
        warehouseRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Auth extends AuthController {
  _Auth(this.permissions);
  final Set<String> permissions;
  void revoke() {
    final current = state.requireValue.session!;
    final user = current.user!;
    state = AsyncData(
      AuthState.authenticated(
        current.withUser(
          AppUser(
            id: user.id,
            name: user.name,
            email: user.email,
            status: user.status,
            profileCode: user.profileCode,
            profileActive: true,
            permissions: const {},
          ),
        ),
      ),
    );
  }

  @override
  Future<AuthState> build() async => AuthState.authenticated(
    AuthSession(
      issuer: 'test',
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      subject: 'operator',
      token: 'test',
      refreshToken: 'test',
      user: AppUser(
        id: 'operator',
        name: 'Maria Operadora',
        email: 'maria@example.test',
        status: 'ACTIVE',
        profileCode: 'OPERADOR',
        profileActive: true,
        permissions: permissions,
      ),
    ),
  );
}

class _Repository extends WarehouseRepository {
  _Repository() : super(Dio());
  final queries = <(int, int, String)>[];
  final lookupQueries = <(int, String)>[];
  bool fail = false;
  @override
  Future<ApiPage<JsonMap>> list(
    String resource, {
    int page = 0,
    int size = 20,
    String q = '',
    Map<String, String> filters = const {},
  }) async {
    queries.add((page, size, q));
    if (fail) throw const ApiException(message: 'Servidor indisponível.');
    return ApiPage(
      content: List.generate(
        size,
        (index) => {
          'id': 'item-${page * size + index}',
          'documentNumber': 'Documento ${page * size + index}',
          'status': 'PENDENTE',
        },
      ),
      page: page,
      size: size,
      totalElements: 41,
      totalPages: (41 / size).ceil(),
      first: page == 0,
      last: page >= (41 / size).ceil() - 1,
    );
  }

  @override
  Future<ApiPage<LookupOption>> lookup(
    String resource, {
    String q = '',
    int page = 0,
    Map<String, String> filters = const {},
  }) async {
    lookupQueries.add((page, q));
    return ApiPage(
      content: List.generate(
        5,
        (i) => LookupOption(
          id: 'position-${page * 5 + i}',
          label: 'Doca legível ${page * 5 + i}',
        ),
      ),
      page: page,
      size: 5,
      totalElements: 10,
      totalPages: 2,
      first: page == 0,
      last: page == 1,
    );
  }
}
