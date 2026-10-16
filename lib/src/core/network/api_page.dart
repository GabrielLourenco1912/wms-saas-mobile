import '../errors/api_exception.dart';

class ApiPage<T> {
  const ApiPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
  final List<T> content;
  final int page, size, totalElements, totalPages;
  final bool first, last;

  factory ApiPage.fromJson(Object? value, T Function(Object?) parse) {
    if (value is! Map<String, dynamic> ||
        value['content'] is! List ||
        value['page'] is! int ||
        value['size'] is! int ||
        value['totalElements'] is! int ||
        value['totalPages'] is! int ||
        value['first'] is! bool ||
        value['last'] is! bool) {
      throw const ApiException(
        message: 'Resposta paginada inválida. Atualize e tente novamente.',
      );
    }
    return ApiPage(
      content: List<T>.unmodifiable((value['content'] as List).map(parse)),
      page: value['page'] as int,
      size: value['size'] as int,
      totalElements: value['totalElements'] as int,
      totalPages: value['totalPages'] as int,
      first: value['first'] as bool,
      last: value['last'] as bool,
    );
  }
}

class LookupOption {
  const LookupOption({required this.id, required this.label});
  final String id, label;
  factory LookupOption.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['label'] is! String) {
      throw const ApiException(
        message: 'Opção de seleção inválida na resposta do servidor.',
      );
    }
    return LookupOption(
      id: value['id'] as String,
      label: value['label'] as String,
    );
  }
}
