import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/core/errors/api_exception.dart';
import 'package:wms_saas_mobile/src/features/operations/application/operation_command.dart';
import 'package:wms_saas_mobile/src/features/operations/data/warehouse_repository.dart';

void main() {
  test(
    'list sends page20 with literal search and structured filters',
    () async {
      final dio = client((request) async {
        expect(request.path, '/api/receipts');
        expect(request.queryParameters, {
          'warehouseId': 'wh-1',
          'status': 'PENDENTE',
          'page': 2,
          'size': 20,
          'q': '% teste_',
        });
        return response(pageData(page: 2));
      });
      final result = await WarehouseRepository(dio).list(
        'receipts',
        page: 2,
        q: ' % teste_ ',
        filters: {'warehouseId': 'wh-1', 'status': 'PENDENTE'},
      );
      expect(result.page, 2);
      expect(result.totalElements, 80);
      expect(result.last, isFalse);
      dio.close();
    },
  );

  test(
    'lookup sends pages of five and decodes label independently of ID',
    () async {
      final dio = client((request) async {
        expect(request.path, '/api/lookups/positions');
        expect(request.queryParameters, {
          'purpose': 'RECEBIMENTO',
          'warehouseId': 'wh-1',
          'page': 1,
          'size': 5,
          'q': 'DOCA',
        });
        return response(
          pageData(
            page: 1,
            size: 5,
            content: [
              {'id': 'pos-1', 'label': 'DOCA-01 · Recebimento'},
            ],
          ),
        );
      });
      final result = await WarehouseRepository(dio).lookup(
        'positions',
        page: 1,
        q: 'DOCA',
        filters: {'purpose': 'RECEBIMENTO', 'warehouseId': 'wh-1'},
      );
      expect(result.content.single.id, 'pos-1');
      expect(result.content.single.label, contains('DOCA-01'));
      dio.close();
    },
  );

  test('packaging list uses backend global search route', () async {
    final dio = client((request) async {
      expect(request.path, '/api/search/product-packages');
      expect(request.queryParameters['productId'], 'prod-1');
      return response(pageData());
    });
    await WarehouseRepository(
      dio,
    ).list('product-packages', filters: {'productId': 'prod-1'});
    dio.close();
  });

  test(
    'invalid page is rejected instead of displaying a false empty result',
    () {
      expect(
        () => ApiPage<JsonMap>.fromJson({
          'content': [],
        }, WarehouseRepository.parseMap),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('field validation retains backend errors and HTTP status', () async {
    final dio = client(
      (_) async => response([
        {'field': 'quantity', 'message': 'Saldo insuficiente.'},
      ], status: 422),
    );
    await expectLater(
      WarehouseRepository(dio).list('stock'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having(
              (e) => e.displayMessage,
              'fields',
              contains('quantity: Saldo insuficiente.'),
            ),
      ),
    );
    dio.close();
  });

  test(
    'concurrent submits share one request and key; later operation gets new key',
    () async {
      final gate = Completer<void>();
      final keys = <String>[];
      final dio = client((request) async {
        keys.add(request.headers['Idempotency-Key'] as String);
        await gate.future;
        return response({'id': 'done'});
      });
      final runner = OperationCommandRunner(dio);
      final first = runner.run(
        '/api/receipts/r/confirm',
        body: {'quantity': 1},
      );
      final second = runner.run(
        '/api/receipts/r/confirm',
        body: {'quantity': 1},
      );
      expect(identical(first, second), isTrue);
      gate.complete();
      await Future.wait([first, second]);
      expect(keys, hasLength(1));
      expect(keys.single.length, lessThanOrEqualTo(64));
      await runner.run('/api/receipts/r/confirm', body: {'quantity': 1});
      expect(keys.toSet(), hasLength(2));
      dio.close();
    },
  );

  test(
    'lost response preserves key for an identical payload regardless of map order',
    () async {
      final keys = <String>[];
      final dio = client((request) async {
        keys.add(request.headers['Idempotency-Key'] as String);
        if (keys.length == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return response({'id': 'confirmed'});
      });
      final runner = OperationCommandRunner(dio);
      await expectLater(
        runner.run(
          '/api/inventories/i/counts',
          body: {
            'items': [
              {'id': 'one', 'quantity': 1},
            ],
            'position': 'A',
          },
        ),
        throwsA(isA<ApiException>()),
      );
      await runner.run(
        '/api/inventories/i/counts',
        body: {
          'position': 'A',
          'items': [
            {'quantity': 1, 'id': 'one'},
          ],
        },
      );
      expect(keys[0], keys[1]);
      dio.close();
    },
  );

  test(
    'outbound key is sent in JSON and retained after server failure',
    () async {
      final keys = <String>[];
      final dio = client((request) async {
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        keys.add((request.data as Map)['idempotencyKey'] as String);
        return response({'id': 'task'}, status: keys.length == 1 ? 503 : 200);
      });
      final runner = OperationCommandRunner(dio);
      await expectLater(
        runner.run('/api/picking-tasks/t/start', keyInBody: true),
        throwsA(isA<ApiException>()),
      );
      await runner.run('/api/picking-tasks/t/start', keyInBody: true);
      expect(keys[0], keys[1]);
      dio.close();
    },
  );

  test(
    'refresh network failure wrapped in original401 keeps operational key',
    () async {
      final keys = <String>[];
      final dio = client((request) async {
        keys.add(request.headers['Idempotency-Key'] as String);
        if (keys.length == 1) {
          throw DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: 401),
            error: const ApiException(message: 'Rede indisponível.'),
          );
        }
        return response({'id': 'confirmed'});
      });
      final runner = OperationCommandRunner(dio);
      await expectLater(
        runner.run('/api/transfers/t/confirm'),
        throwsA(isA<ApiException>()),
      );
      await runner.run('/api/transfers/t/confirm');
      expect(keys[0], keys[1]);
      dio.close();
    },
  );

  test('definite validation failure permits a new logical attempt', () async {
    final keys = <String>[];
    final dio = client((request) async {
      keys.add(request.headers['Idempotency-Key'] as String);
      return response({
        'id': 'confirmed',
      }, status: keys.length == 1 ? 422 : 200);
    });
    final runner = OperationCommandRunner(dio);
    await expectLater(
      runner.run('/api/stock/s/block', body: {'reason': 'Conferência'}),
      throwsA(isA<ApiException>()),
    );
    await runner.run('/api/stock/s/block', body: {'reason': 'Conferência'});
    expect(keys[0], isNot(keys[1]));
    dio.close();
  });
}

JsonMap pageData({
  int page = 0,
  int size = 20,
  List<JsonMap> content = const [],
}) => {
  'content': content,
  'page': page,
  'size': size,
  'totalElements': 80,
  'totalPages': (80 / size).ceil(),
  'first': page == 0,
  'last': false,
};
Dio client(Future<ResponseBody> Function(RequestOptions) callback) =>
    Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = _Adapter(callback);
ResponseBody response(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({
        'timestamp': '2026-10-15T12:00:00',
        'status': '$status OK',
        'message': 'Resposta',
        'data': data,
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _Adapter implements HttpClientAdapter {
  _Adapter(this.callback);
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
