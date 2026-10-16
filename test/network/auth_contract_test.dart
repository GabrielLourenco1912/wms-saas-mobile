import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/core/errors/api_exception.dart';
import 'package:wms_saas_mobile/src/features/auth/data/datasources/auth_remote_data_source.dart';

void main() {
  test(
    'mobile login receives a challenge and verification preserves code zeros',
    () async {
      final calls = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = CallbackAdapter((request) {
          calls.add(request);
          expect(request.headers['X-Client-Type'], 'MOBILE');
          if (request.path == '/api/auth/login') {
            return response(202, {
              'challengeId': 'challenge',
              'purpose': 'MFA_LOGIN',
              'maskedEmail': 'm***@example.com',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 10))
                  .toIso8601String(),
              'maxAttempts': 5,
            });
          }
          expect(request.path, '/api/auth/challenge/verify');
          expect(request.data, {'challengeId': 'challenge', 'code': '012345'});
          return response(200, tokens());
        });
      final remote = DioAuthRemoteDataSource(dio);
      final challenge = await remote.login(
        email: ' maria@example.com ',
        password: 'password',
      );
      expect(challenge.id, 'challenge');
      expect(calls.single.data, {
        'email': 'maria@example.com',
        'password': 'password',
      });
      final session = await remote.verifyChallenge(
        challengeId: challenge.id,
        code: '012345',
      );
      expect(session.refreshToken, 'refresh-new');
      expect(session.refreshTokenExpiresAt, isNotNull);
      dio.close();
    },
  );

  test(
    'refresh and logout transport current refresh token with MOBILE header',
    () async {
      final paths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = CallbackAdapter((request) {
          paths.add(request.path);
          expect(request.headers['X-Client-Type'], 'MOBILE');
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(request.data, {
            'refreshToken': request.path.endsWith('refresh')
                ? 'refresh-old'
                : 'refresh-new',
          });
          return response(
            200,
            request.path.endsWith('refresh') ? tokens() : null,
          );
        });
      final remote = DioAuthRemoteDataSource(dio);
      final updated = await remote.refresh(refreshToken: 'refresh-old');
      await remote.logout(updated.refreshToken);
      expect(paths, ['/api/auth/refresh', '/api/auth/logout']);
      dio.close();
    },
  );

  test('password recovery sends reset directly to reset-password', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = CallbackAdapter((request) {
        expect(request.path, '/api/auth/reset-password');
        expect(request.data, {
          'challengeId': 'recovery',
          'code': '000123',
          'newPassword': 'nova-senha',
        });
        expect(request.headers['X-Client-Type'], 'MOBILE');
        return response(200, null);
      });
    await DioAuthRemoteDataSource(dio).resetPassword(
      challengeId: 'recovery',
      code: '000123',
      newPassword: 'nova-senha',
    );
    dio.close();
  });

  test(
    'web-only token response is rejected by mobile instead of losing refresh',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = CallbackAdapter(
          (_) => response(200, tokens()..remove('refreshToken')),
        );
      await expectLater(
        DioAuthRemoteDataSource(dio).refresh(refreshToken: 'old'),
        throwsA(isA<ApiException>()),
      );
      dio.close();
    },
  );
}

Map<String, Object?> tokens() => {
  'issuer': 'wms',
  'issuedAt': DateTime.now().toUtc().toIso8601String(),
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
  'subject': 'user-1',
  'token': 'new',
  'refreshToken': 'refresh-new',
  'refreshTokenExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(days: 30))
      .toIso8601String(),
};

ResponseBody response(int status, Object? data) => ResponseBody.fromString(
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

class CallbackAdapter implements HttpClientAdapter {
  CallbackAdapter(this.callback);
  final ResponseBody Function(RequestOptions request) callback;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => callback(options);
  @override
  void close({bool force = false}) {}
}
