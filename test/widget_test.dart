import 'package:flutter_test/flutter_test.dart';
import 'package:ifinance/core/utils/money.dart';

void main() {
  group('Money — valores em centavos (sem float)', () {
    test('parse converte texto pt-BR em centavos', () {
      expect(Money.parse('10,50'), 1050);
      expect(Money.parse('R\$ 1.234,56'), 123456);
      expect(Money.parse('1000'), 100000);
      expect(Money.parse(''), isNull);
    });

    test('splitInstallments não perde centavos', () {
      final parts = Money.splitInstallments(100, 3);
      expect(parts.reduce((a, b) => a + b), 100);
      expect(parts.length, 3);
    });

    test('sum é soma inteira segura', () {
      expect(Money.sum([1050, 2000, 50]), 3100);
    });
  });
}
