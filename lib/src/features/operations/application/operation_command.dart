import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_dio_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../auth/application/auth_controller.dart';
import '../data/warehouse_repository.dart';

final operationCommandProvider = Provider<OperationCommandRunner>((ref) {
  ref.watch(authControllerProvider.select((state) => state.value?.user?.id));
  return OperationCommandRunner(ref.watch(apiDioProvider));
});

/// Keeps the same key when a response is lost. A retry sends the exact payload;
/// stock is updated only by the server. There is no automatic offline replay.
class OperationCommandRunner {
  OperationCommandRunner(this.dio);
  final Dio dio;
  final _pendingKeys = <String, String>{};
  final _inFlight = <String, Future<JsonMap>>{};
  final _random = Random.secure();

  Future<JsonMap> run(
    String path, {
    JsonMap? body,
    bool keyInBody = false,
    String method = 'POST',
  }) {
    final payload = body == null ? null : _canonical(body);
    final identity = jsonEncode([
      method.toUpperCase(),
      path,
      keyInBody,
      payload,
    ]);
    final existing = _inFlight[identity];
    if (existing != null) return existing;
    final key = _pendingKeys.putIfAbsent(
      identity,
      () => List.generate(
        24,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
    );
    final pending = _send(
      path,
      method,
      payload as JsonMap?,
      keyInBody,
      key,
      identity,
    );
    _inFlight[identity] = pending;
    return pending;
  }

  Future<JsonMap> _send(
    String path,
    String method,
    JsonMap? body,
    bool keyInBody,
    String key,
    String identity,
  ) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: keyInBody ? {...?body, 'idempotencyKey': key} : body,
        options: Options(
          method: method,
          headers: {if (!keyInBody) 'Idempotency-Key': key},
        ),
      );
      final result = ApiEnvelope<JsonMap>.fromJson(
        response.data,
        WarehouseRepository.parseMap,
      ).data;
      if (result == null) {
        throw const ApiException(
          message:
              'O servidor não retornou o resultado. Atualize antes de repetir.',
        );
      }
      _pendingKeys.remove(identity);
      return result;
    } on DioException catch (error) {
      // A definite validation/authorization rejection did not commit the command.
      // Timeouts, 409 and server failures keep the original idempotency key.
      final apiError = ApiException.fromDio(error);
      if ([400, 401, 403, 404, 422].contains(apiError.statusCode)) {
        _pendingKeys.remove(identity);
      }
      throw apiError;
    } finally {
      _inFlight.remove(identity);
    }
  }

  Object? _canonical(Object? value) {
    if (value is Map<String, dynamic>) {
      final keys = value.keys.toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is List) return value.map(_canonical).toList(growable: false);
    return value;
  }
}
