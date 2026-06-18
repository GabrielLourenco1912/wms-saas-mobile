import '../errors/api_exception.dart';

class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.timestamp,
    required this.status,
    required this.message,
    required this.data,
  });

  final String timestamp;
  final String status;
  final String message;
  final T? data;

  factory ApiEnvelope.fromJson(
    Object? json,
    T Function(Object? json) parseData,
  ) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException(message: 'Resposta da API em formato inválido.');
    }

    return ApiEnvelope<T>(
      timestamp: json['timestamp']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'] == null ? null : parseData(json['data']),
    );
  }
}
