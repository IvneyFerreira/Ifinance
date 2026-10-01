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
    // A 1ª ocorrência de regras mensais+ é alinhada ao dia preferencial
    // (ex.: 5º dia útil) — nunca fica presa a uma `startDate` desalinhada.
    var cursor = _initialCursor(rule);
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

  /// Próxima ocorrência da regra a partir de [from] (inclusive) — usada por
  /// telas que mostram "próxima" (ex.: lista de recorrências). Garante a mesma
  /// data exibida no Radar/projeções.
  static DateTime? nextOccurrence(RecurringRule rule, {DateTime? from}) {
    final base = DateHelpers.dateOnly(from ?? DateTime.now());
    if (!rule.active) return null;
    final horizonEnd = DateHelpers.addMonths(base, 61);
    final occ = occurrencesInWindow(rule, base, horizonEnd);
    return occ.isEmpty ? null : occ.first;
  }

  /// Primeira ocorrência da série. Para frequências mensais+ com dia
  /// preferencial, é a data alinhada ao dia no mês da `startDate`; se essa data
  /// já tiver passado da `startDate`, avança para o mês seguinte.
  static DateTime _initialCursor(RecurringRule rule) {
    final start = DateHelpers.dateOnly(rule.startDate);
    if (!_isMonthBased(rule.frequency) || rule.preferredDayOfMonth == null) {
      return start;
    }
    var candidate = _occurrenceInMonth(rule, start.year, start.month);
    if (candidate.isBefore(start)) {
      final nm = DateTime(start.year, start.month + 1, 1);
      candidate = _occurrenceInMonth(rule, nm.year, nm.month);
    }
    return candidate;
  }

  static bool _isMonthBased(RecurrenceFrequency f) =>
      f != RecurrenceFrequency.weekly &&
      f != RecurrenceFrequency.biweekly &&
      f != RecurrenceFrequency.custom;

  /// Data de ocorrência no mês informado conforme o dia preferencial da regra
  /// (N-ésimo dia útil quando [RecurringRule.useBusinessDay]; caso contrário,
  /// dia fixo — movido para o 1º dia útil seguinte se cair em fim de semana).
  static DateTime _occurrenceInMonth(RecurringRule rule, int year, int month) {
    final day = (rule.preferredDayOfMonth ??
            DateHelpers.dateOnly(rule.startDate).day)
        .clamp(1, DateHelpers.daysInMonth(year, month));
    if (rule.useBusinessDay) {
      final nth = DateHelpers.nthBusinessDay(year, month, day);
      if (nth != null) return nth;
    }
    return DateHelpers.businessDayAdjusted(year, month, day);
  }

  static DateTime _next(RecurringRule rule, DateTime current) {
    switch (rule.frequency) {
      case RecurrenceFrequency.weekly:
        return DateHelpers.addDays(current, 7);
      case RecurrenceFrequency.biweekly:
        return DateHelpers.addDays(current, 14);
      case RecurrenceFrequency.monthly:
        return _addMonthsOccurrence(rule, current, 1);
      case RecurrenceFrequency.bimonthly:
        return _addMonthsOccurrence(rule, current, 2);
      case RecurrenceFrequency.quarterly:
        return _addMonthsOccurrence(rule, current, 3);
      case RecurrenceFrequency.semiannual:
        return _addMonthsOccurrence(rule, current, 6);
      case RecurrenceFrequency.annual:
        return _addMonthsOccurrence(rule, current, 12);
      case RecurrenceFrequency.custom:
        return DateHelpers.addDays(
          current,
          rule.customIntervalDays.clamp(1, 366),
        );
    }
  }

  /// Ocorrência [months] meses após [current], alinhada ao dia preferencial
  /// (N-ésimo dia útil, ou dia fixo com rolagem de fim de semana).
  static DateTime _addMonthsOccurrence(
    RecurringRule rule,
    DateTime current,
    int months,
  ) {
    final base = DateHelpers.addMonths(current, months);
    if (rule.preferredDayOfMonth == null) return base;
    return _occurrenceInMonth(rule, base.year, base.month);
  }
}
