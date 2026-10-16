/// Quantities accepted by the inbound API: at most 12 integer and 6 decimal
/// digits. A comma is accepted by the mobile form and normalized before send.
String? inboundQuantityError(String? value) {
  final normalized = (value ?? '').trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,12}(\.\d{1,6})?$').hasMatch(normalized)) {
    return 'Informe uma quantidade com até 12 inteiros e 6 decimais.';
  }
  final scaled = scaledInboundQuantity(normalized);
  if (scaled == BigInt.zero) {
    return 'A quantidade precisa ser maior que zero.';
  }
  final number = num.tryParse(normalized);
  final transported = number is int
      ? number.toString()
      : number?.toStringAsFixed(6);
  if (transported == null || scaledInboundQuantity(transported) != scaled) {
    return 'Esta quantidade perde precisão no aplicativo. Use um valor menor ou com menos casas decimais.';
  }
  return null;
}

BigInt? scaledInboundQuantity(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,12}(\.\d{1,6})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  return BigInt.parse(parts.first) * BigInt.from(1000000) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(6, '0'));
}

String? integralPutawayQuantityError(String? value, Object? target) {
  final error = inboundQuantityError(value);
  if (error != null) return error;
  final expected = scaledInboundQuantity(target.toString());
  if (expected == null || scaledInboundQuantity(value!) != expected) {
    return 'Confirme a quantidade integral do LPN: $target.';
  }
  return null;
}

String inboundText(Object? value, {String fallback = 'Não informado'}) =>
    value == null || value.toString().trim().isEmpty
    ? fallback
    : value.toString();

List<Map<String, dynamic>> inboundMaps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

String inboundStatus(Object? value) => switch (value) {
  'PENDENTE' => 'Pendente',
  'EM_RECEBIMENTO' => 'Em recebimento',
  'EM_EXECUCAO' => 'Em execução',
  'ATENDIDO' => 'Atendido',
  'CONCLUIDA' => 'Concluída',
  'CANCELADA' || 'CANCELADO' => 'Cancelado',
  _ => inboundText(value),
};
