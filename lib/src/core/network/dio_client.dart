import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

final authDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

BaseOptions _baseOptions() {
  return BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Client-Type': 'MOBILE',
    },
  );
}
