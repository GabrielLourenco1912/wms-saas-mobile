import 'package:flutter_test/flutter_test.dart';
import 'package:wms_saas_mobile/src/features/operations/presentation/pages/inbound/inbound_contracts.dart';

void main() {
  group('Validação das quantidades de entrada', () {
    test('aceita vírgula e precisão decimal sem arredondamento', () {
      expect(inboundQuantityError('12,123456'), isNull);
      expect(scaledInboundQuantity('12,123456'), BigInt.from(12123456));
      expect(inboundQuantityError('999999999999.999999'), isNotNull);
      expect(
        scaledInboundQuantity('999999999999.999999'),
        BigInt.parse('999999999999999999'),
      );
    });

    test('rejeita valores não positivos e formato fora do contrato', () {
      for (final invalid in [
        '',
        '0',
        '0.000000',
        '-1',
        '1.0000001',
        '1000000000000',
        'NaN',
        'Infinity',
        '1e3',
        '1,2,3',
      ]) {
        expect(inboundQuantityError(invalid), isNotNull, reason: invalid);
      }
    });

    test('putaway exige o conteúdo integral do LPN', () {
      expect(integralPutawayQuantityError('24,000000', 24), isNull);
      expect(integralPutawayQuantityError('23.999999', 24), isNotNull);
      expect(integralPutawayQuantityError('24.000001', 24), isNotNull);
      expect(integralPutawayQuantityError('0', 24), isNotNull);
      expect(integralPutawayQuantityError('1', null), isNotNull);
    });
  });
}
