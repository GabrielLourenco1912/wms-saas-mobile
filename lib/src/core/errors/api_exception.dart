import 'package:dio/dio.dart';

class FieldError {
  const FieldError({required this.field, required this.message});

  final String field;
  final String message;

  factory FieldError.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const FieldError(field: 'campo', message: 'Valor inválido.');
    }

    return FieldError(
      field: json['field']?.toString() ?? 'campo',
      message: json['message']?.toString() ?? 'Valor inválido.',
    );
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.status,
    this.statusCode,
    this.fieldErrors = const [],
  });

  final String message;
  final String? status;
  final int? statusCode;
  final List<FieldError> fieldErrors;

  String get displayMessage {
    if (fieldErrors.isEmpty) {
      return message;
    }

    final errors = fieldErrors
        .map((error) => '${error.field}: ${error.message}')
        .join('\n');
    return '$message\n$errors';
  }

  factory ApiException.fromDio(DioException error) {
    if (error.error case final ApiException exception) return exception;
    final response = error.response;
    final data = response?.data;

    if (data is Map<String, dynamic>) {
      final rawErrors = data['data'];
      final fieldErrors = rawErrors is List
          ? rawErrors.map(FieldError.fromJson).toList(growable: false)
          : const <FieldError>[];

      return ApiException(
        message:
            data['message']?.toString() ?? 'Falha na comunicação com a API.',
        status: data['status']?.toString(),
        statusCode: response?.statusCode,
        fieldErrors: fieldErrors,
      );
    }

    return ApiException(
      message: switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'A conexão demorou para responder. Verifique sua rede e tente novamente.',
        DioExceptionType.connectionError =>
          'Não foi possível conectar ao servidor. Verifique sua conexão.',
        DioExceptionType.cancel => 'Solicitação cancelada.',
        _ => 'Não foi possível concluir a solicitação. Tente novamente.',
      },
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => displayMessage;
}
