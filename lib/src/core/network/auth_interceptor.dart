import 'package:dio/dio.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../errors/api_exception.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required AuthRepository authRepository,
    required Future<void> Function() onSessionExpired,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _authRepository = authRepository,
       _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final AuthRepository _authRepository;
  final Future<void> Function() _onSessionExpired;

  Future<void> _expire() async {
    try {
      await _onSessionExpired();
    } catch (_) {
      /* Navigation is already unauthenticated. */
    }
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final session = await _tokenStorage.read();
      final subject = session?.subject ?? '';
      final originalSubject = options.extra['authSubject'];
      final originalRevision = options.extra['authRevision'];
      if ((originalSubject != null && originalSubject != subject) ||
          (originalRevision != null &&
              originalRevision != _authRepository.sessionRevision)) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: const ApiException(
              message:
                  'A conta da sessão mudou. Atualize a tela antes de continuar.',
              statusCode: 401,
            ),
          ),
        );
        return;
      }
      options.extra['authSubject'] = subject;
      options.extra['authRevision'] = _authRepository.sessionRevision;
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.token}';
      } else {
        options.headers.remove('Authorization');
      }
      options.headers['X-Client-Type'] = 'MOBILE';
      handler.next(options);
    } catch (error, stack) {
      handler.reject(
        DioException(requestOptions: options, error: error, stackTrace: stack),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    try {
      final stored = await _tokenStorage.read();
      if (stored != null &&
          (request.extra['authSubject'] != stored.subject ||
              request.extra['authRevision'] !=
                  _authRepository.sessionRevision)) {
        handler.next(
          DioException(
            requestOptions: request,
            type: DioExceptionType.cancel,
            error: const ApiException(
              message:
                  'A conta da sessão mudou. Atualize a tela antes de continuar.',
              statusCode: 401,
            ),
          ),
        );
        return;
      }
      if (request.extra['authRetry'] == true) {
        await _expire();
        handler.next(err);
        return;
      }
      if (stored == null || !stored.canRefresh) {
        await _expire();
        handler.next(err);
        return;
      }
      final failedToken =
          request.headers['Authorization']?.toString().replaceFirst(
            'Bearer ',
            '',
          ) ??
          stored.token;
      final refreshed = await _authRepository.refresh(
        accessToken: failedToken,
        refreshToken: stored.refreshToken,
      );
      final response = await _dio.fetch<Object?>(
        request.copyWith(
          headers: {
            ...request.headers,
            'Authorization': 'Bearer ${refreshed.token}',
          },
          extra: {...request.extra, 'authRetry': true},
        ),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      // Preserve an actual retry failure (403, conflict, network, etc.).
      handler.next(retryError);
    } on ApiException catch (refreshError) {
      if (refreshError.statusCode == 400 ||
          refreshError.statusCode == 401 ||
          refreshError.statusCode == 403) {
        final latest = await _tokenStorage.read();
        final sameSession =
            request.extra['authRevision'] == _authRepository.sessionRevision &&
            request.extra['authSubject'] == latest?.subject;
        if (latest == null || sameSession) await _expire();
      }
      handler.reject(
        DioException(
          requestOptions: request,
          response: err.response,
          error: refreshError,
          message: refreshError.displayMessage,
        ),
      );
    } catch (refreshError, stack) {
      handler.reject(
        DioException(
          requestOptions: request,
          error: refreshError,
          stackTrace: stack,
        ),
      );
    }
  }
}
