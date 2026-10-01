import 'package:flutter_test/flutter_test.dart';

import 'package:ifinance/core/finance/finance_engine.dart';
import 'package:ifinance/core/finance/finance_models.dart';
import 'package:ifinance/core/models/models.dart';
import 'package:ifinance/core/utils/date_helpers.dart';

// ---------------------------------------------------------------------------
// Regressão: "Livre seguro" NÃO pode contar apenas as saídas do período.
// O horizonte (ex.: "Mês") inclui o dia do salário; se as receitas previstas
// forem ignoradas, o indicador fica irrealmente negativo e contradiz a
// "Projeção do mês" exibida logo abaixo na Home.
// ---------------------------------------------------------------------------

const String uid = 'user-1';

final DateTime _now = DateTime.now();
final DateTime _day10 = DateTime(_now.year, _now.month, 10);
final DateTime _endMonth = DateHelpers.endOfMonth(_now);

FinanceEngine engineWith({
  List<Transaction> txs = const [],
  List<RecurringRule> rules = const [],
}) => FinanceEngine(
  userId: uid,
  accounts: [
    Account(
      id: 'acc1',
      userId: uid,
      name: 'Conta',
      balanceCents: 100000, // R$ 1.000,00
      createdAt: _now,
      updatedAt: _now,
    ),
  ],
  transactions: txs,
  categories: const [],
  cards: const [],
  installments: const [],
  purchases: const [],
  recurringRules: rules,
  subscriptions: const [],
  settings: const UserSettings(userId: uid, safetyMarginPercent: 10),
);

Transaction tx({
  required String id,
  required TransactionType type,
  required int amount,
  DateTime? due,
  DateTime? paidAt,
  ExpenseStatus? expenseStatus,
  IncomeStatus? incomeStatus,
  String description = 'Lançamento',
}) => Transaction(
  id: id,
  userId: uid,
  accountId: 'acc1',
  type: type,
  description: description,
  amountCents: amount,
  competenceDate: due ?? _day10,
  dueDate: due ?? _day10,
  paidAt: paidAt,
  expenseStatus: expenseStatus ?? ExpenseStatus.pending,
  incomeStatus: incomeStatus ?? IncomeStatus.expected,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('getExpectedIncomeAmount', () {
    test('soma receitas ainda não recebidas dentro do horizonte', () {
      final e = engineWith(
        txs: [
          tx(
            id: 'i1',
            type: TransactionType.income,
            amount: 500000,
            due: _day10,
          ),
        ],
      );
      expect(e.getExpectedIncomeAmount(until: _day10), 500000);
    });

    test('receita já RECEBIDA não é contada (já está no saldo)', () {
      final e = engineWith(
        txs: [
          tx(
            id: 'i1',
            type: TransactionType.income,
            amount: 500000,
            due: _day10,
            paidAt: _day10,
            incomeStatus: IncomeStatus.received,
          ),
        ],
      );
      expect(e.getExpectedIncomeAmount(until: _endMonth), 0);
    });

    test('receita após o horizonte não conta', () {
      final e = engineWith(
        txs: [
          tx(
            id: 'i1',
            type: TransactionType.income,
            amount: 500000,
            due: DateHelpers.addMonths(_day10, 2),
          ),
        ],
      );
      expect(e.getExpectedIncomeAmount(until: _day10), 0);
    });
  });

  group('getSafeAvailableBalance — receitas previstas entram no cálculo', () {
    test('inclui a entrada prevista do horizonte (não só as saídas)', () {
      final e = engineWith(
        txs: [
          tx(
            id: 'i1',
            type: TransactionType.income,
            amount: 500000, // salário
            due: _day10,
          ),
          tx(
            id: 'e1',
            type: TransactionType.expense,
            amount: 200000, // conta a pagar
            due: _day10,
          ),
        ],
      );
      // 100000 + 500000 − 200000 = 400000; margem 10% = 40000 → 360000.
      expect(e.getSafeAvailableBalance(until: _day10), 360000);
    });

    test('sem receitas previstas o comportamento clássico permanece', () {
      final e = engineWith(
        txs: [
          tx(
            id: 'e1',
            type: TransactionType.expense,
            amount: 200000,
            due: _day10,
          ),
        ],
      );
      // 100000 − 200000 = −100000; margem 10% = −10000 → −90000.
      expect(e.getSafeAvailableBalance(until: _day10), -90000);
    });

    test('receita recorrente equivalente NÃO é contada em dobro', () {
      final rule = RecurringRule(
        id: 'r1',
        userId: uid,
        description: 'Salário',
        type: TransactionType.income,
        amountCents: 500000,
        accountId: 'acc1',
        frequency: RecurrenceFrequency.monthly,
        startDate: _now,
        preferredDayOfMonth: _now.day,
        createdAt: _now,
        updatedAt: _now,
      );
      final e = engineWith(
        rules: [rule],
        txs: [
          tx(
            id: 'i1',
            type: TransactionType.income,
            amount: 500000,
            description: 'Salário',
            due: _now,
          ),
        ],
      );
      // O lançamento real + a recorrência do mesmo mês = uma única entrada.
      expect(e.getExpectedIncomeAmount(until: _endMonth), 500000);
    });
  });

  group('DashboardData', () {
    test('expõe receitas previstas para a Home', () {
      final e = engineWith(
        txs: [
          tx(
            id: 'i1',
            type: TransactionType.income,
            amount: 500000,
            due: _day10,
          ),
        ],
      );
      final d = e.buildDashboard(Horizon.month);
      expect(d.expectedIncomeCents, 500000);
    });
  });
}
