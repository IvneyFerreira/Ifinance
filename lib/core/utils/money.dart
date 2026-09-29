import 'package:intl/intl.dart';

/// IFinance — Valores monetários.
///
/// REGRA CRÍTICA (cap. 60): Nunca utilizar float/double para dinheiro.
/// Todos os valores são armazenados e calculados como inteiros
/// representando CENTAVOS. Ex.: R$ 10,50 == 1050 centavos.
class Money {
  Money._();

  static final NumberFormat _brl = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final NumberFormat _brlCompact = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 0,
  );

  /// Formata centavos para o padrão monetário brasileiro.
  /// Ex.: 1050 -> "R$ 10,50"
  static String format(int cents, {bool showSign = false}) {
    final value = cents / 100;
    final text = _brl.format(value);
    if (showSign && cents > 0) return '+ $text';
    return text;
  }

  /// Formata sem casas decimais (para blocos grandes).
  static String formatCompact(int cents) => _brlCompact.format(cents / 100);

  /// Ex.: 1050 -> "1.050,00" (sem símbolo)
  static String formatPlain(int cents) {
    final f = NumberFormat('#,##0.00', 'pt_BR');
    return f.format(cents / 100);
  }

  /// Converte texto do usuário ("10,50", "1050", "R$ 10,50") em centavos.
  static int? parse(String input) {
    if (input.trim().isEmpty) return null;
    var cleaned = input
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }

  /// Soma segura (inteiros, sem erro de ponto flutuante).
  static int sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);

  /// Aplica percentual a um valor em centavos (arredonda para o centavo).
  static int applyPercent(int cents, double percent) =>
      (cents * percent / 100).round();

  /// Percentual de `part` sobre `whole` (0..100+). Retorna 0 se whole == 0.
  static double percentOf(int part, int whole) {
    if (whole == 0) return 0;
    return (part / whole) * 100;
  }

  /// Distribui um total em N parcelas sem perder centavos.
  /// Ex.: 100 / 3 -> [34, 33, 33]
  static List<int> splitInstallments(int totalCents, int n) {
    if (n <= 0) return const [];
    final base = totalCents ~/ n;
    final remainder = totalCents - base * n;
    return List<int>.generate(n, (i) => base + (i < remainder ? 1 : 0));
  }

  static String formatPercent(double value) {
    final f = NumberFormat('#,##0.#', 'pt_BR');
    return '${f.format(value)}%';
  }
}
