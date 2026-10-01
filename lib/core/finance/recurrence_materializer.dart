import '../models/models.dart';
import '../utils/date_helpers.dart';

/// Materializa ocorrências de recorrências sob demanda (cap. 22).
/// NÃO gera fisicamente anos de lançamentos — apenas as ocorrências
/// contidas na janela solicitada (projeção, calendário, radar).
class RecurrenceMaterializer {
  RecurrenceMaterializer._();

  /// Retorna as datas de ocorrência de uma regra dentro de [from, to].
  static List<DateTime> occurrencesInWindow(
    RecurringRule rule,
    DateTime from,
    DateTime to,
  ) {
    final start = DateHelpers.dateOnly(rule.startDate);
    final end = DateHelpers.dateOnly(to);
    final windowStart = DateHelpers.dateOnly(from);
    final result = <DateTime>[];

    if (!rule.active) return result;
    if (start.isAfter(end)) return result;
    if (rule.endDate != null && rule.endDate!.isBefore(windowStart)) {
      return result;
    }

    var count = 0;
    var cursor = start;
    // Proteção contra loops infinitos.
    var guard = 0;

    while (!cursor.isAfter(end) && guard < 4000) {
      guard++;
      // Limite de ocorrências definidas.
      if (rule.totalOccurrences != null && count >= rule.totalOccurrences!) {
        break;
      }
      // Fim por data.
      if (rule.endDate != null && cursor.isAfter(rule.endDate!)) break;

      if (!cursor.isBefore(windowStart)) {
        result.add(cursor);
      }
      count++;
      cursor = _next(rule, cursor);
    }
    return result;
  }

  static DateTime _next(RecurringRule rule, DateTime current) {
    switch (rule.frequency) {
      case RecurrenceFrequency.weekly:
        return DateHelpers.addDays(current, 7);
      case RecurrenceFrequency.biweekly:
        return DateHelpers.addDays(current, 14);
      case RecurrenceFrequency.monthly:
        return _addMonthKeepDay(
          current,
          1,
          rule.preferredDayOfMonth,
          rule.useBusinessDay,
        );
      case RecurrenceFrequency.bimonthly:
        return _addMonthKeepDay(
          current,
          2,
          rule.preferredDayOfMonth,
          rule.useBusinessDay,
        );
      case RecurrenceFrequency.quarterly:
        return _addMonthKeepDay(
          current,
          3,
          rule.preferredDayOfMonth,
          rule.useBusinessDay,
        );
      case RecurrenceFrequency.semiannual:
        return _addMonthKeepDay(
          current,
          6,
          rule.preferredDayOfMonth,
          rule.useBusinessDay,
        );
      case RecurrenceFrequency.annual:
        return _addMonthKeepDay(
          current,
          12,
          rule.preferredDayOfMonth,
          rule.useBusinessDay,
        );
      case RecurrenceFrequency.custom:
        return DateHelpers.addDays(
          current,
          rule.customIntervalDays.clamp(1, 366),
        );
    }
  }

  /// Calcula a ocorrência do mês seguinte (mensal+).
  ///
  /// - [useBusinessDay] = true → [preferredDay] é o **N-ésimo dia útil** do mês
  ///   (ex.: 5º dia útil, comum em salários).
  /// - [useBusinessDay] = false → [preferredDay] é um **dia fixo**; se cair em
  ///   fim de semana, é movido para o primeiro dia útil seguinte.
  static DateTime _addMonthKeepDay(
    DateTime current,
    int months,
    int? preferredDay,
    bool useBusinessDay,
  ) {
    final base = DateHelpers.addMonths(current, months);
    if (preferredDay == null) return base;
    final day = preferredDay.clamp(
      1,
      DateHelpers.daysInMonth(base.year, base.month),
    );
    if (useBusinessDay) {
      final nth = DateHelpers.nthBusinessDay(base.year, base.month, day);
      if (nth != null) return nth;
    }
    // Dia fixo: rola para o primeiro dia útil se cair em fim de semana.
    return DateHelpers.businessDayAdjusted(base.year, base.month, day);
  }
}
