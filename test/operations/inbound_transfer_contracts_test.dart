import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/stock/transfer_contracts.dart';

void main() {
  test('formata soma decimal das camadas sem perder as seis casas', () {
    expect(inboundDecimalFromScaled(BigInt.zero), '0');
    expect(inboundDecimalFromScaled(BigInt.one), '0.000001');
    expect(inboundDecimalFromScaled(BigInt.from(24000100)), '24.0001');
    expect(
      inboundDecimalFromScaled(BigInt.parse('999999999999999999')),
      '999999999999.999999',
    );
  });

  test('permite quantidade parcial no saldo sem ultrapassar o disponível', () {
    expect(transferQuantityError('1,123456', '2.123456'), isNull);
    expect(transferQuantityError('2.123457', '2.123456'), isNotNull);
    expect(transferQuantityError('0', '2.123456'), isNotNull);
  });

  test('LPN integral não aceita confirmar apenas uma parte', () {
    expect(transferQuantityError('24.000000', 24, wholeLpn: true), isNull);
    expect(transferQuantityError('23', 24, wholeLpn: true), isNotNull);
  });
}
