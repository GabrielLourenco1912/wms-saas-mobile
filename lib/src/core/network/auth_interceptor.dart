import 'package:dio/dio.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required AuthRemoteDataSource authRemoteDataSource,
    required Future<void> Function() onSessionExpired,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _authRemoteDataSource = authRemoteDataSource,
       _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final AuthRemoteDataSource _authRemoteDataSource;
  final Future<void> Function() _onSessionExpired;

  Future<AuthSession>? _refreshFuture;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = await _tokenStorage.read();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.token}';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final shouldRefresh =
        err.response?.statusCode == 401 && request.extra['authRetry'] != true;

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    final storedSession = await _tokenStorage.read();
    if (storedSession == null) {
      handler.next(err);
      return;
    }

    try {
      final refreshedSession = await _refreshOnce(storedSession);
      final retryOptions = request.copyWith(
        headers: {
          ...request.headers,
          'Authorization': 'Bearer ${refreshedSession.token}',
        },
        extra: {...request.extra, 'authRetry': true},
      );

      final retryResponse = await _dio.fetch<Object?>(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      await _onSessionExpired();
      handler.next(err);
    }
  }

  Future<AuthSession> _refreshOnce(AuthSession session) {
    final pendingRefresh = _refreshFuture;
    if (pendingRefresh != null) {
      return pendingRefresh;
    }

    final refresh = _authRemoteDataSource
        .refresh(accessToken: session.token, refreshToken: session.refreshToken)
        .then((newSession) async {
          await _tokenStorage.save(newSession);
          return newSession;
        })
        .whenComplete(() => _refreshFuture = null);

    _refreshFuture = refresh;
    return refresh;
  }
}
