import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/core/errors/api_exception.dart';
import 'package:wms_saas_mobile/src/core/network/auth_interceptor.dart';
import 'package:wms_saas_mobile/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:wms_saas_mobile/src/features/auth/domain/entities/auth_session.dart';

import '../auth/auth_repository_test.dart' as support;

void main() {
  test(
    'an old refresh cannot expire a new login of the same account',
    () async {
      final storage = support.MemoryTokenStorage(support.session('old'));
      final remote = support.FakeAuthRemote();
      final refreshStarted = Completer<void>();
      final refreshResult = Completer<AuthSession>();
      remote.onRefresh = (_) {
        refreshStarted.complete();
        return refreshResult.future;
      };
      final repository = RemoteAuthRepository(remote, storage);
      var expirations = 0;
      var requests = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = _Adapter((_) {
          requests++;
          return result(401);
        });
      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          tokenStorage: storage,
          authRepository: repository,
          onSessionExpired: () async {
            expirations++;
            await storage.clear();
          },
        ),
      );
      final request = dio.get<Object?>('/api/stock');
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await refreshStarted.future;
      await repository.logout();
      await repository.verifyChallenge(
        challengeId: 'new-login',
        code: '123456',
      );
      expect(storage.value?.token, 'new');
      refreshResult.complete(support.session('old-session-refreshed'));
      await assertion;
      expect(requests, 1);
      expect(expirations, 0);
      expect(storage.value?.token, 'new');
      expect(storage.value?.subject, 'user-1');
      dio.close();
    },
  );

  test(
    'a request from the previous account cannot retry as the new account',
    () async {
      final storage = support.MemoryTokenStorage(support.session('old'));
      final remote = support.FakeAuthRemote();
      var requests = 0;
      var expirations = 0;
      final dio = client(
        storage,
        remote,
        (_) {
          requests++;
          final newTokens = support.session('account-b');
          storage.value = AuthSession(
            issuer: newTokens.issuer,
            issuedAt: newTokens.issuedAt,
            expiresAt: newTokens.expiresAt,
            subject: 'user-2',
            token: newTokens.token,
            refreshToken: newTokens.refreshToken,
            refreshTokenExpiresAt: newTokens.refreshTokenExpiresAt,
          );
          return result(401);
        },
        () async {
          expirations++;
        },
      );
      await expectLater(
        dio.post<Object?>('/api/tasks/task/start'),
        throwsA(isA<DioException>()),
      );
      expect(requests, 1);
      expect(remote.refreshCalls, 0);
      expect(expirations, 0);
      expect(storage.value?.subject, 'user-2');
      dio.close();
    },
  );

  test(
    'simultaneous 401s share one rotation and preserve mutation idempotency',
    () async {
      final storage = support.MemoryTokenStorage(support.session('old'));
      final remote = support.FakeAuthRemote();
      final gate = Completer<AuthSession>();
      remote.onRefresh = (_) => gate.future;
      final requests = <RequestOptions>[];
      var expirations = 0;
      final dio = client(
        storage,
        remote,
        (request) {
          requests.add(request);
          expect(request.headers['X-Client-Type'], 'MOBILE');
          expect(request.headers['Idempotency-Key'], 'operation-1');
          expect(request.data, {'quantity': 5});
          return result(
            request.headers['Authorization'] == 'Bearer old' ? 401 : 200,
          );
        },
        () async {
          expirations++;
        },
      );
      final first = dio.post<Object?>(
        '/api/tasks/task/start',
        data: {'quantity': 5},
        options: Options(headers: {'Idempotency-Key': 'operation-1'}),
      );
      final second = dio.post<Object?>(
        '/api/tasks/task/start',
        data: {'quantity': 5},
        options: Options(headers: {'Idempotency-Key': 'operation-1'}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(remote.refreshCalls, 1);
      gate.complete(support.session('new'));
      expect((await first).statusCode, 200);
      expect((await second).statusCode, 200);
      expect(remote.refreshCalls, 1);
      expect(expirations, 0);
      expect(requests.length, 4);
      dio.close();
    },
  );

  test('a 403 is never refreshed', () async {
    final storage = support.MemoryTokenStorage(support.session('old'));
    final remote = support.FakeAuthRemote();
    var expirations = 0;
    final dio = client(storage, remote, (_) => result(403), () async {
      expirations++;
    });
    await expectLater(
      dio.get<Object?>('/api/stock'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          403,
        ),
      ),
    );
    expect(remote.refreshCalls, 0);
    expect(expirations, 0);
    expect(storage.value, isNotNull);
    dio.close();
  });

  test(
    'a forbidden retry preserves its 403 without destroying the session',
    () async {
      final storage = support.MemoryTokenStorage(support.session('old'));
      final remote = support.FakeAuthRemote();
      var expirations = 0;
      final dio = client(
        storage,
        remote,
        (request) => result(
          request.headers['Authorization'] == 'Bearer old' ? 401 : 403,
        ),
        () async {
          expirations++;
        },
      );
      await expectLater(
        dio.get<Object?>('/api/stock'),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
      expect(remote.refreshCalls, 1);
      expect(expirations, 0);
      expect(storage.value?.token, 'new');
      dio.close();
    },
  );

  test('a second 401 expires session without a refresh loop', () async {
    final storage = support.MemoryTokenStorage(support.session('old'));
    final remote = support.FakeAuthRemote();
    var expirations = 0;
    var requests = 0;
    final dio = client(
      storage,
      remote,
      (_) {
        requests++;
        return result(401);
      },
      () async {
        expirations++;
        await storage.clear();
      },
    );
    await expectLater(
      dio.get<Object?>('/api/stock'),
      throwsA(isA<DioException>()),
    );
    expect(remote.refreshCalls, 1);
    expect(requests, 2);
    expect(expirations, 1);
    expect(storage.value, isNull);
    dio.close();
  });

  test(
    'an offline refresh preserves credentials and its network error',
    () async {
      final storage = support.MemoryTokenStorage(support.session('old'));
      final remote = support.FakeAuthRemote()
        ..onRefresh = (_) async =>
            throw const ApiException(message: 'Sem conexão.');
      var expirations = 0;
      final dio = client(storage, remote, (_) => result(401), () async {
        expirations++;
      });
      await expectLater(
        dio.get<Object?>('/api/stock'),
        throwsA(
          isA<DioException>().having(
            (error) => ApiException.fromDio(error).message,
            'message',
            'Sem conexão.',
          ),
        ),
      );
      expect(expirations, 0);
      expect(storage.value?.token, 'old');
      dio.close();
    },
  );
}

Dio client(
  support.MemoryTokenStorage storage,
  support.FakeAuthRemote remote,
  ResponseBody Function(RequestOptions) callback,
  Future<void> Function() onExpire,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = _Adapter(callback);
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokenStorage: storage,
      authRepository: RemoteAuthRepository(remote, storage),
      onSessionExpired: onExpire,
    ),
  );
  return dio;
}

ResponseBody result(int status) => ResponseBody.fromString(
  jsonEncode({
    'data': null,
    'message': status == 200 ? 'ok' : 'Erro',
    'status': '$status',
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.callback);
  final ResponseBody Function(RequestOptions) callback;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => callback(options);
  @override
  void close({bool force = false}) {}
}
