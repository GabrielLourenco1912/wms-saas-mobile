import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/app/app.dart';
import 'package:wms_saas_mobile/src/app/router/app_router.dart';
import 'package:wms_saas_mobile/src/core/network/api_dio_provider.dart';
import 'package:wms_saas_mobile/src/core/network/dio_client.dart';
import 'package:wms_saas_mobile/src/core/storage/token_storage.dart';
import 'package:wms_saas_mobile/src/features/auth/application/auth_controller.dart';
import 'package:wms_saas_mobile/src/features/auth/presentation/pages/login_page.dart';

import 'auth_repository_test.dart' as support;

void main() {
  testWidgets(
    'real app keeps login mounted through POST 202, verifies code, and opens dashboard',
    (tester) async {
      final loginResponse = Completer<ResponseBody>();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = _AsyncAdapter((request) async {
          if (request.path == '/api/auth/login') {
            expect(request.headers['X-Client-Type'], 'MOBILE');
            return loginResponse.future;
          }
          if (request.path == '/api/auth/challenge/verify') {
            expect(request.headers['X-Client-Type'], 'MOBILE');
            expect(request.data, {
              'challengeId': 'challenge-1',
              'code': '012345',
            });
            return _response(200, {
              'issuer': 'wms',
              'subject': 'user-1',
              'token': 'new-access',
              'refreshToken': 'new-refresh',
              'issuedAt': DateTime.now().toUtc().toIso8601String(),
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
              'refreshTokenExpiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 30))
                  .toIso8601String(),
            });
          }
          expect(request.path, '/api/users/me');
          expect(request.headers['Authorization'], 'Bearer new-access');
          return _response(200, {
            'id': 'user-1',
            'name': 'Maria',
            'email': 'maria@example.com',
            'status': 'ACTIVE',
            'profileCode': 'OPERADOR',
            'profileActive': true,
            'permissions': <String>[],
          });
        });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              support.MemoryTokenStorage(),
            ),
            authDioProvider.overrideWithValue(dio),
            apiDioProvider.overrideWithValue(dio),
          ],
          child: const WmsMobileApp(),
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
      await tester.pump();
      expect(container.read(authControllerProvider).isLoading, isTrue);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login',
      );
      expect(find.byType(LoginPage), findsOneWidget);
      loginResponse.complete(
        _response(202, {
          'challengeId': 'challenge-1',
          'purpose': 'MFA_LOGIN',
          'maskedEmail': 'm***@example.com',
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
          'maxAttempts': 5,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirme seu acesso'), findsOneWidget);
      expect(
        container.read(authControllerProvider).value?.isAuthenticated,
        isFalse,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-code')),
        '012345',
      );
      await tester.ensureVisible(find.text('Verificar e entrar'));
      await tester.tap(find.text('Verificar e entrar'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/dashboard',
      );
      expect(find.text('Olá, Maria'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      dio.close();
    },
  );

  testWidgets(
    'real app exposes password recovery without authentication or public registration',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              support.MemoryTokenStorage(),
            ),
          ],
          child: const WmsMobileApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginPage)),
      );
      expect(find.text('Criar uma conta para a operação'), findsNothing);
      await tester.ensureVisible(find.text('Esqueci minha senha'));
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/forgot-password',
      );
      expect(find.text('Recuperar acesso'), findsOneWidget);
      expect(find.text('Enviar código'), findsOneWidget);
    },
  );
}

ResponseBody _response(int status, Object? data) => ResponseBody.fromString(
  jsonEncode({
    'timestamp': 'now',
    'status': '$status OK',
    'message': 'ok',
    'data': data,
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _AsyncAdapter implements HttpClientAdapter {
  _AsyncAdapter(this.callback);
  final Future<ResponseBody> Function(RequestOptions) callback;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => callback(options);
  @override
  void close({bool force = false}) {}
}
