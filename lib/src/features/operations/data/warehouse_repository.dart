import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_dio_provider.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_page.dart';
export '../../../core/network/api_page.dart';

typedef JsonMap = Map<String, dynamic>;

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  // Recreate account-scoped clients when the authenticated identity changes.
  ref.watch(authControllerProvider.select((state) => state.value?.user?.id));
  return WarehouseRepository(ref.watch(apiDioProvider));
});

class WarehouseRepository {
  WarehouseRepository(this.dio);
  final Dio dio;

  Future<ApiPage<JsonMap>> list(
    String resource, {
    int page = 0,
    int size = 20,
    String q = '',
    Map<String, String> filters = const {},
  }) async {
    final path = resource == 'product-packages'
        ? 'search/product-packages'
        : resource;
    final value = await _get(
      '/api/$path',
      query: {
        ...filters,
        'page': page,
        'size': size,
        if (q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    return ApiPage.fromJson(value, parseMap);
  }

  Future<JsonMap> detail(String resource, String id) async =>
      parseMap(await _get('/api/$resource/${Uri.encodeComponent(id)}'));

  Future<ApiPage<LookupOption>> lookup(
    String resource, {
    String q = '',
    int page = 0,
    Map<String, String> filters = const {},
  }) async {
    final value = await _get(
      '/api/lookups/$resource',
      query: {
        ...filters,
        'page': page,
        'size': 5,
        if (q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    return ApiPage.fromJson(value, LookupOption.fromJson);
  }

  Future<Object?> _get(String path, {JsonMap? query}) async {
    try {
      final response = await dio.get<Object?>(path, queryParameters: query);
      return ApiEnvelope<Object?>.fromJson(
        response.data,
        (value) => value,
      ).data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  static JsonMap parseMap(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Resposta do servidor em formato inválido.',
      );
    }
    return value;
  }
}
