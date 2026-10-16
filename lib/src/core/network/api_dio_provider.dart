import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'dio_client.dart';

final apiDioProvider = Provider<Dio>((ref) {
  final source = ref.watch(authDioProvider).options;
  final dio = Dio(
    BaseOptions(
      baseUrl: source.baseUrl,
      connectTimeout: source.connectTimeout,
      receiveTimeout: source.receiveTimeout,
      headers: Map<String, Object?>.from(source.headers),
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokenStorage: ref.watch(tokenStorageProvider),
      authRepository: ref.watch(authRepositoryProvider),
      onSessionExpired: () =>
          ref.read(authControllerProvider.notifier).expireSession(),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
