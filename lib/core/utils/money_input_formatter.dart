import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// IFinance — Máscara monetária (pt-BR).
///
/// Digitação livre converte para o padrão brasileiro automaticamente:
///   3000  -> 3.000,00
///   12,5  -> 12,50
///   1500,75 -> 1.500,75
///
/// Estratégia (estilo "caixa registradora"): os dígitos digitados são sempre
/// interpretados como centavos, do mais significativo ao menos significativo.
/// Assim, digitar "3", "0", "0", "0" produz 00,03 -> 00,30 -> 03,00 -> 30,00.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter({this.symbol = 'R\$ '});

  final String symbol;

  static final NumberFormat _fmt = NumberFormat('#,##0.00', 'pt_BR');

  /// Extrai apenas dígitos da "parte numérica" da string.
  static String _digits(String raw) {
    // Remove o símbolo, espaços e separadores; mantém só dígitos.
    var s = raw.replaceAll('R\$', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return '';
    // Remove zeros à esquerda para evitar estouro, mantendo ao menos 1.
    s = s.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return s;
  }

  /// Formata uma quantidade de centavos (string de dígitos) para exibição.
  static String formatFromDigits(String digits) {
    if (digits.isEmpty) return '';
    final cents = int.parse(digits);
    return _fmt.format(cents / 100);
  }

  /// Formata um valor em centavos para exibição (sem símbolo).
  static String formatCents(int cents) => _fmt.format(cents / 100);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digits(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final text = formatFromDigits(digits);
    // Cursor sempre no fim (comportamento de máscara numérica).
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Extensão de ajuda: converte o texto mascarado em centavos.
class MoneyInput {
  MoneyInput._();

  /// "R$ 3.000,00" ou "3.000,00" -> 300000 centavos.
  static int? parse(String input) {
    final digits = MoneyInputFormatter._digits(input);
    if (digits.isEmpty) return null;
    final cents = int.tryParse(digits);
    if (cents == null || cents <= 0) return null;
    return cents;
  }
}
