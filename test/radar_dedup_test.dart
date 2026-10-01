import 'package:flutter_test/flutter_test.dart';

import 'package:ifinance/core/finance/finance_engine.dart';
import 'package:ifinance/core/models/models.dart';

/// O Radar não pode mostrar "duas vezes" a mesma receita/despesa recorrente
/// quando existe um lançamento real equivalente no mesmo mês (a data pode
/// variar — feriado/dia útil — dentro do mês).
void main() {
  final t = DateTime(2026, 10, 1);

  RecurringRule salary({required bool business, required int day}) =>
      RecurringRule(
        id: 'rule1',
        userId: 'u1',
        description: 'Salário',
        type: TransactionType.income,
        amountCents: 445000,
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 10, 7),
        preferredDayOfMonth: day,
        useBusinessDay: business,
        createdAt: t,
        updatedAt: t,
      );

  Transaction realIncome(DateTime d) => Transaction(
        id: 'tx1',
        userId: 'u1',
        accountId: 'acc1',
        type: TransactionType.income,
        description: 'Salário',
        amountCents: 445000,
        competenceDate: d,
        dueDate: d,
        paidAt: d,
        incomeStatus: IncomeStatus.received,
        createdAt: t,
        updatedAt: t,
      );

  Account acc() => Account(
        id: 'acc1',
        userId: 'u1',
        name: 'Conta',
        balanceCents: 0,
        createdAt: t,
        updatedAt: t,
      );

  FinanceEngine engineWith({
    required List<Transaction> txns,
    required List<RecurringRule> rules,
  }) =>
      FinanceEngine(
        userId: 'u1',
        accounts: [acc()],
        transactions: txns,
        categories: const [],
        cards: const [],
        installments: const [],
        purchases: const [],
        recurringRules: rules,
        subscriptions: const [],
        settings: const UserSettings(userId: 'u1'),
      );

  group('Radar — deduplicação de recorrência x lançamento real', () {
    test('sem lançamento real: projeta a ocorrência (5º dia útil)', () {
      final engine = engineWith(
        txns: [],
        rules: [salary(business: true, day: 5)],
      );
      final events = engine
          .cashEvents(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31))
          .where((e) => e.amountCents > 0)
          .toList();
      // Apenas a projeção da recorrência.
      expect(events.length, 1);
      expect(events.first.date, DateTime(2026, 10, 7));
    });

    test('lançamento real no mesmo mês (data próxima) não duplica', () {
      final engine = engineWith(
        // Lançamento real no dia 08/10; a recorrência projetaria 07/10.
        txns: [realIncome(DateTime(2026, 10, 8))],
        rules: [salary(business: true, day: 5)],
      );
      final doubles = engine
          .cashEvents(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31))
          .where((e) => e.amountCents > 0)
          .toList();
      // Deve sobrar apenas 1 entrada de salário (o lançamento real).
      expect(doubles.length, 1);
      expect(doubles.first.confirmed, isTrue);
    });

    test('lançamento real no mesmo mês com data distante também deduplica',
        () {
      final engine = engineWith(
        // Real no dia 25/10; a projeção seria 07/10 — >5 dias, mas mesmo mês.
        txns: [realIncome(DateTime(2026, 10, 25))],
        rules: [salary(business: true, day: 5)],
      );
      final salaries = engine
          .cashEvents(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31))
          .where((e) => e.amountCents > 0)
          .toList();
      expect(salaries.length, 1);
    });
  });
}
