import '../../../../core/errors/api_exception.dart';
import '../../domain/entities/auth_session.dart';

class AuthSessionModel {
  const AuthSessionModel._();

  static AuthSession fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException(message: 'Payload de autenticação inválido.');
    }

    final token = json['token']?.toString() ?? '';
    final refreshToken = json['refreshToken']?.toString() ?? '';
    if (token.isEmpty || refreshToken.isEmpty) {
      throw const ApiException(
        message: 'Resposta de sessão mobile sem tokens.',
      );
    }
    return AuthSession(
      issuer: json['issuer']?.toString() ?? '',
      issuedAt: _parseDate(json['issuedAt'], 'issuedAt'),
      expiresAt: _parseDate(json['expiresAt'], 'expiresAt'),
      subject: json['subject']?.toString() ?? '',
      token: token,
      refreshToken: refreshToken,
      refreshTokenExpiresAt: json['refreshTokenExpiresAt'] == null
          ? null
          : _parseDate(json['refreshTokenExpiresAt'], 'refreshTokenExpiresAt'),
    );
  }

  static DateTime _parseDate(Object? value, String field) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      throw ApiException(message: 'Campo $field ausente no payload de auth.');
    }

    return DateTime.parse(raw).toUtc();
  }
}
