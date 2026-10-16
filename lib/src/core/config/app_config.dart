import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get apiBaseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 20);
}
