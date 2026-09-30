import 'package:intl/intl.dart';

/// Helpers de datas — diferenciando competência, vencimento, pagamento e criação
/// (cap. 61). Todas as datas são normalizadas (somente dia) quando relevante.
class DateHelpers {
  DateHelpers._();

  static final DateFormat dayMonth = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat fullDate = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat monthLong = DateFormat('MMMM', 'pt_BR');
  static final DateFormat monthYear = DateFormat('MMMM yyyy', 'pt_BR');
  static final DateFormat weekdayShort = DateFormat('EEE', 'pt_BR');
  static final DateFormat iso = DateFormat('yyyy-MM-dd');

  /// Hora no padrão brasileiro ("14:35").
  static final DateFormat time = DateFormat('HH:mm', 'pt_BR');

  /// "2026-03-12" (para CSV/backup).
  static String isoDate(DateTime d) => iso.format(dateOnly(d));

  static const List<String> monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const List<String> weekdayNames = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 0, 23, 59, 59);

  static DateTime firstDayNextMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 1);

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static int daysBetween(DateTime a, DateTime b) =>
      dateOnly(b).difference(dateOnly(a)).inDays;

  static int daysUntil(DateTime d) => daysBetween(DateTime.now(), d);

  static DateTime addMonths(DateTime d, int months) {
    final targetMonth = d.month - 1 + months;
    final year = d.year + (targetMonth ~/ 12);
    final month = (targetMonth % 12) + 1;
    final day = d.day.clamp(1, daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static DateTime addDays(DateTime d, int days) => d.add(Duration(days: days));

  /// "Hoje", "Amanhã", "Ontem" ou "dd/MM"
  static String friendly(DateTime d) {
    final today = dateOnly(DateTime.now());
    final target = dateOnly(d);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    if (diff == -1) return 'Ontem';
    if (diff > 1 && diff <= 7) return 'Em $diff dias';
    return dayMonth.format(d);
  }

  static String monthLabel(DateTime d, {bool withYear = false}) => withYear
      ? '${monthNames[d.month - 1]} ${d.year}'
      : monthNames[d.month - 1];

  /// Diferença de meses entre duas datas (a -> b).
  static int monthsBetween(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);

  /// Gera lista de meses (primeiro dia) entre from e to (inclusive).
  static List<DateTime> monthRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, 1);
    final end = DateTime(to.year, to.month, 1);
    final result = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Dias úteis (cap. 51) — usados para datas de recebimento como "5º dia útil".
  // Consideramos dias úteis de segunda a sexta (feriados não são considerados).
  // ---------------------------------------------------------------------------

  /// `true` se [d] cai em um dia útil (segunda a sexta).
  static bool isBusinessDay(DateTime d) =>
      d.weekday != DateTime.saturday && d.weekday != DateTime.sunday;

  /// Nome do dia da semana em português ("Segunda", "Terça", ...).
  static String weekdayName(DateTime d) => weekdayNames[d.weekday - 1];

  /// Data do [n]-ésimo dia útil do mês informado (1 = primeiro dia útil).
  /// Retorna `null` se [n] for menor que 1.
  static DateTime? nthBusinessDay(int year, int month, int n) {
    if (n < 1) return null;
    final dim = daysInMonth(year, month);
    var count = 0;
    for (var day = 1; day <= dim; day++) {
      final d = DateTime(year, month, day);
      if (isBusinessDay(d)) {
        count++;
        if (count == n) return d;
      }
    }
    return null;
  }

  /// Próxima ocorrência do [n]-ésimo dia útil a partir de [from] (inclusive).
  /// Se o dia útil do mês atual já passou, retorna o do mês seguinte.
  static DateTime? nextNthBusinessDay(int n, {DateTime? from}) {
    final base = dateOnly(from ?? DateTime.now());
    final current = nthBusinessDay(base.year, base.month, n);
    if (current != null && !current.isBefore(base)) return current;
    final next = DateTime(base.year, base.month + 1, 1);
    return nthBusinessDay(next.year, next.month, n);
  }

  /// Próxima ocorrência do dia fixo [day] a partir de [from] (inclusive).
  /// Se o dia já passou neste mês, retorna o do mês seguinte.
  static DateTime nextFixedDay(int day, {DateTime? from}) {
    final base = dateOnly(from ?? DateTime.now());
    final clampedDay = day.clamp(1, daysInMonth(base.year, base.month));
    final current = DateTime(base.year, base.month, clampedDay);
    if (!current.isBefore(base)) return current;
    final next = DateTime(base.year, base.month + 1, 1);
    return DateTime(
      next.year,
      next.month,
      day.clamp(1, daysInMonth(next.year, next.month)),
    );
  }
}
