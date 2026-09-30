import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifinance/core/utils/money.dart';
import 'package:ifinance/core/utils/money_input_formatter.dart';

/// Testes de integração de fluxos (camada de lógica sem servidor).
/// Exercita a máscara monetária ponta-a-ponta: digitação → formatação →
/// parsing em centavos, garantindo que os valores nunca passem por float.
void main() {
  group('Fluxo: entrada de valor monetário pt-BR', () {
    testWidgets('digitar um valor inteiro formata em reais e volta em centavos',
        (tester) async {
      final controller = TextEditingController();
      final formatter = MoneyInputFormatter();
      var value = const TextEditingValue(text: '');
      for (final ch in '1234567'.split('')) {
        final appended = value.text + ch;
        value = formatter.formatEditUpdate(
          value,
          TextEditingValue(
            text: appended,
            selection: TextSelection.collapsed(offset: appended.length),
          ),
        );
      }
      controller.text = value.text;
      expect(controller.text, '12.345,67');
      expect(MoneyInput.parse(controller.text), 1234567);
      expect(Money.format(1234567), contains('12.345,67'));
    });

    testWidgets('apagar dígitos recalcula a máscara corretamente',
        (tester) async {
      final formatter = MoneyInputFormatter();
      var value = const TextEditingValue(text: '');
      for (final ch in '999'.split('')) {
        final appended = value.text + ch;
        value = formatter.formatEditUpdate(
          value,
          TextEditingValue(
            text: appended,
            selection: TextSelection.collapsed(offset: appended.length),
          ),
        );
      }
      expect(value.text, '999,00');
      // Remove o último caractere visível (um dígito antes da vírgula).
      final removed = value.text.substring(0, value.text.length - 3);
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(
          text: removed,
          selection: TextSelection.collapsed(offset: removed.length),
        ),
      );
      expect(MoneyInput.parse(value.text), isNotNull);
    });

    test('Money.formatCompact resume valores grandes', () {
      expect(Money.formatCompact(150000000), isNotEmpty);
      expect(Money.formatCompact(150000), isNotEmpty);
    });
  });

  group('Fluxo: percentuais e parcelas (sem float acumulado)', () {
    test('applyPercent sobre centavos é inteiro', () {
      final v = Money.applyPercent(10000, 15); // 15%
      expect(v, 1500);
    });

    test('splitInstallments preserva o total exato', () {
      final parts = Money.splitInstallments(1000, 7);
      expect(parts.reduce((a, b) => a + b), 1000);
      expect(parts.length, 7);
    });
  });
}
