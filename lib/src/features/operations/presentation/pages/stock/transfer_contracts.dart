import '../inbound/inbound_contracts.dart';

String inboundDecimalFromScaled(BigInt value) {
  final digits = value.toString().padLeft(7, '0');
  final integer = digits.substring(0, digits.length - 6);
  final fraction = digits
      .substring(digits.length - 6)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? integer : '$integer.$fraction';
}

String? transferQuantityError(
  String? value,
  Object? maximum, {
  bool wholeLpn = false,
}) {
  final error = inboundQuantityError(value);
  if (error != null) return error;
  final limit = scaledInboundQuantity('$maximum');
  final quantity = scaledInboundQuantity(value!);
  if (limit == null || quantity == null) {
    return 'A quantidade de referência está indisponível. Atualize a consulta.';
  }
  if (wholeLpn && quantity != limit) {
    return 'Informe a quantidade integral do LPN: $maximum.';
  }
  if (quantity > limit) return 'A quantidade não pode ultrapassar $maximum.';
  return null;
}
