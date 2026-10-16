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
  Future<AuthChallenge> login({
    required String email,
    required String password,
  });
  Future<AuthSession> verifyChallenge({
    required String challengeId,
    required String code,
  });
  Future<AuthChallenge> forgotPassword(String email);
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  });
  Future<AuthSession> refresh({required String refreshToken});
  Future<AppUser> currentUser(String token);
  Future<void> logout(String refreshToken);
}

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  const DioAuthRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<AuthChallenge> login({
    required String email,
    required String password,
  }) async => AuthChallenge.fromJson(
    await _post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    }),
  );

  @override
  Future<AuthSession> verifyChallenge({
    required String challengeId,
    required String code,
  }) async => AuthSessionModel.fromJson(
    await _post('/api/auth/challenge/verify', {
      'challengeId': challengeId,
      'code': code,
    }),
  );

  @override
  Future<AuthChallenge> forgotPassword(String email) async =>
      AuthChallenge.fromJson(
        await _post('/api/auth/forgot-password', {'email': email.trim()}),
      );

  @override
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  }) async {
    await _post('/api/auth/reset-password', {
      'challengeId': challengeId,
      'code': code,
      'newPassword': newPassword,
    });
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async =>
      AuthSessionModel.fromJson(
        await _post('/api/auth/refresh', {'refreshToken': refreshToken}),
      );

  @override
  Future<void> logout(String refreshToken) async {
    await _post('/api/auth/logout', {'refreshToken': refreshToken});
  }

  @override
  Future<AppUser> currentUser(String token) async {
    try {
      final response = await _dio.get<Object?>(
        '/api/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final envelope = ApiEnvelope<AppUser>.fromJson(
        response.data,
        AppUser.fromJson,
      );
      return envelope.data ??
          (throw const ApiException(
            message: 'Não foi possível carregar seu perfil.',
          ));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Object?> _post(String path, Map<String, Object?> data) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: data,
        options: Options(headers: {'X-Client-Type': 'MOBILE'}),
      );
      return ApiEnvelope<Object?>.fromJson(
        response.data,
        (value) => value,
      ).data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
