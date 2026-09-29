import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifinance/core/utils/money.dart';
import 'package:ifinance/core/utils/money_input_formatter.dart';

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

  group('MoneyInputFormatter — máscara automática (pt-BR)', () {
    test('3000 reais -> 3.000,00', () {
      expect(MoneyInputFormatter.formatReais(3000), '3.000,00');
    });

    test('300000 centavos -> 3.000,00', () {
      expect(MoneyInputFormatter.formatCents(300000), '3.000,00');
    });

    test('formatação de centavos pt-BR', () {
      expect(MoneyInputFormatter.formatCents(150075), '1.500,75');
      expect(MoneyInputFormatter.formatCents(1299), '12,99');
      expect(MoneyInputFormatter.formatCents(123456789), '1.234.567,89');
    });

    test('parse do texto mascarado devolve centavos', () {
      expect(MoneyInput.parse('R\$ 3.000,00'), 300000);
      expect(MoneyInput.parse('1.500,75'), 150075);
      expect(MoneyInput.parse(''), isNull);
    });

    testWidgets('digitar 3000 produz 3.000,00', (tester) async {
      final controller = TextEditingController();
      final formatter = MoneyInputFormatter();
      var value = const TextEditingValue(text: '');
      for (final ch in ['3', '0', '0', '0']) {
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
      expect(controller.text, '3.000,00');
      expect(MoneyInput.parse(controller.text), 300000);
    });

    testWidgets('digitar 12,99 produz 12,99', (tester) async {
      final formatter = MoneyInputFormatter();
      var value = const TextEditingValue(text: '');
      for (final ch in ['1', '2', ',', '9', '9']) {
        final appended = value.text + ch;
        value = formatter.formatEditUpdate(
          value,
          TextEditingValue(
            text: appended,
            selection: TextSelection.collapsed(offset: appended.length),
          ),
        );
      }
      expect(value.text, '12,99');
      expect(MoneyInput.parse(value.text), 1299);
    });
  });
}
