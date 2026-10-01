import 'package:flutter_test/flutter_test.dart';

import 'package:ifinance/core/finance/recurrence_materializer.dart';
import 'package:ifinance/core/models/models.dart';

/// A série de uma recorrência mensal com "N-ésimo dia útil" deve ser alinhada
/// ao dia útil de CADA mês — inclusive a primeira ocorrência — e não ficar
/// presa à `startDate` gravada (que pode estar desalinhada).
void main() {
  RecurringRule monthly({
    required DateTime startDate,
    required int day,
    required bool business,
  }) =>
      RecurringRule(
        id: 'r1',
        userId: 'u1',
        description: 'Salário',
        type: TransactionType.income,
        amountCents: 445000,
        frequency: RecurrenceFrequency.monthly,
        startDate: startDate,
        preferredDayOfMonth: day,
        useBusinessDay: business,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  group('Recorrência mensal — alinhamento ao dia útil', () {
    test('5º dia útil: out/26=07, nov/26=06, dez/26=07', () {
      final occ = RecurrenceMaterializer.occurrencesInWindow(
        monthly(startDate: DateTime(2026, 10, 7), day: 5, business: true),
        DateTime(2026, 10, 1),
        DateTime(2026, 12, 31),
      );
      expect(occ, [
        DateTime(2026, 10, 7),
        DateTime(2026, 11, 6),
        DateTime(2026, 12, 7),
      ]);
    });

    test('7º dia útil com startDate desalinhado é corrigido (09/10)', () {
      // startDate = 07/10 (5º dia útil), mas a regra agora é 7º dia útil.
      final occ = RecurrenceMaterializer.occurrencesInWindow(
        monthly(startDate: DateTime(2026, 10, 7), day: 7, business: true),
        DateTime(2026, 10, 1),
        DateTime(2026, 12, 31),
      );
      // Out/26: 7º dia útil = 09/10; Nov/26 = 10/11; Dez/26 = 09/12.
      expect(occ.first, DateTime(2026, 10, 9));
      expect(occ, [
        DateTime(2026, 10, 9),
        DateTime(2026, 11, 10),
        DateTime(2026, 12, 9),
      ]);
    });

    test('dia fixo em fim de semana rola para o 1º dia útil', () {
      // Dia 3 de jan/2027 = domingo -> segunda 04/01/2027.
      final occ = RecurrenceMaterializer.occurrencesInWindow(
        monthly(startDate: DateTime(2027, 1, 3), day: 3, business: false),
        DateTime(2027, 1, 1),
        DateTime(2027, 2, 28),
      );
      expect(occ.first, DateTime(2027, 1, 4));
    });


    test('nextOccurrence retorna a próxima real, não a startDate', () {
      final rule = monthly(
          startDate: DateTime(2026, 8, 7), day: 5, business: true);
      final next = RecurrenceMaterializer.nextOccurrence(
        rule,
        from: DateTime(2026, 10, 1),
      );
      expect(next, DateTime(2026, 10, 7));
    });
  });
}

// Nota: a deduplicação por mês (Radar x lançamento real) é coberta pelos
// testes de finance_engine em ambientes com transactions; aqui validamos o
// núcleo de alinhamento de datas.
