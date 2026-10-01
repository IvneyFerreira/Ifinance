import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:ifinance/core/finance/finance_engine.dart';
import 'package:ifinance/core/models/models.dart';
import 'package:ifinance/core/services/assessor_api.dart';

/// O contexto enviado à IA precisa conter as PREVISÕES (o que ainda vai
/// acontecer) — não apenas o que já foi lançado no mês.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
    Intl.defaultLocale = 'pt_BR';
  });

  final t = DateTime(2026, 10, 1);

  Account acc() => Account(
        id: 'acc1',
        userId: 'u1',
        name: 'Conta',
        balanceCents: 1000000,
        createdAt: t,
        updatedAt: t,
      );

  RecurringRule salary() => RecurringRule(
        id: 'rule1',
        userId: 'u1',
        description: 'Salário',
        type: TransactionType.income,
        amountCents: 445000,
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 10, 7),
        preferredDayOfMonth: 5,
        useBusinessDay: true,
        createdAt: t,
        updatedAt: t,
      );

  RecurringRule rent() => RecurringRule(
        id: 'rule2',
        userId: 'u1',
        description: 'Aluguel',
        type: TransactionType.expense,
        amountCents: 350000,
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 10, 5),
        preferredDayOfMonth: 5,
        createdAt: t,
        updatedAt: t,
      );

  FinanceEngine engine() => FinanceEngine(
        userId: 'u1',
        accounts: [acc()],
        transactions: const [],
        categories: const [],
        cards: const [],
        installments: const [],
        purchases: const [],
        recurringRules: [salary(), rent()],
        subscriptions: const [],
        settings: const UserSettings(userId: 'u1'),
      );

  group('Contexto da IA — previsões', () {
    test('inclui seção forecast com salário e aluguel previstos', () {
      final ctx = FinancialContext.build(engine(), const []);
      expect(ctx.containsKey('forecast'), isTrue);
      final forecast = ctx['forecast'] as Map<String, dynamic>;
      expect(forecast.containsKey('upcoming'), isTrue);
      expect(forecast.containsKey('remainingThisMonth'), isTrue);
      expect(forecast.containsKey('nextMonths'), isTrue);

      final upcoming = forecast['upcoming'] as List;
      final labels = upcoming.map((e) => (e as Map)['label']).toList();
      expect(labels.contains('Salário'), isTrue);
      expect(labels.contains('Aluguel'), isTrue);
    });

    test('projeção dos próximos meses tem entradas e saídas', () {
      final ctx = FinancialContext.build(engine(), const []);
      final months =
          (ctx['forecast'] as Map<String, dynamic>)['nextMonths'] as List;
      expect(months.length, 3);
      final first = months.first as Map;
      // Salário 4.450 e aluguel 3.500 previstos -> resultado positivo.
      expect(first['expectedIncome'], isNot('R\$ 0,00'));
      expect(first['expectedExpense'], isNot('R\$ 0,00'));
    });
  });
}
