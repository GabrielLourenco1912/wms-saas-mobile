import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'dio_client.dart';

final apiDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_cloneBaseOptions(ref.watch(authDioProvider).options));

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokenStorage: ref.watch(tokenStorageProvider),
      authRemoteDataSource: ref.watch(authRemoteDataSourceProvider),
      onSessionExpired: () =>
          ref.read(authControllerProvider.notifier).logout(),
    ),
  );

  return dio;
});

BaseOptions _cloneBaseOptions(BaseOptions source) {
  return BaseOptions(
    baseUrl: source.baseUrl,
    connectTimeout: source.connectTimeout,
    receiveTimeout: source.receiveTimeout,
    headers: Map<String, Object?>.from(source.headers),
  );
}
