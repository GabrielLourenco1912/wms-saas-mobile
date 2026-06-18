import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/auth_session.dart';
import '../models/auth_session_model.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return DioAuthRemoteDataSource(ref.watch(authDioProvider));
});

abstract class AuthRemoteDataSource {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> refresh({
    required String accessToken,
    required String refreshToken,
  });
}

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  const DioAuthRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    return _postAuth(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _postAuth(
      '/api/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
  }

  @override
  Future<AuthSession> refresh({
    required String accessToken,
    required String refreshToken,
  }) {
    return _postAuth(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<AuthSession> _postAuth(
    String path, {
    required Map<String, Object?> data,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: data,
        options: options,
      );
      final envelope = ApiEnvelope<AuthSession>.fromJson(
        response.data,
        AuthSessionModel.fromJson,
      );
      final session = envelope.data;

      if (session == null) {
        throw ApiException(
          message: envelope.message.isEmpty
              ? 'Resposta de autenticação sem sessão.'
              : envelope.message,
          status: envelope.status,
          statusCode: response.statusCode,
        );
      }

      return session;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
