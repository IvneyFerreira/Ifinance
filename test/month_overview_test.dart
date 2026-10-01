import 'package:flutter_test/flutter_test.dart';

import 'package:ifinance/core/finance/finance_engine.dart';
import 'package:ifinance/core/models/models.dart';
import 'package:ifinance/core/utils/date_helpers.dart';

// ---------------------------------------------------------------------------
// Visão mensal (MonthOverview): separar o que já entrou/saiu do que ainda falta
// pagar/receber, contar contas em aberto e calcular o valor livre seguro.
// ---------------------------------------------------------------------------

const String uid = 'user-1';
final DateTime _now = DateTime.now();
final DateTime _start = DateHelpers.startOfMonth(_now);

FinanceEngine engineWith(List<Transaction> txs) => FinanceEngine(
  userId: uid,
  accounts: [
    Account(
      id: 'acc1',
      userId: uid,
      name: 'Conta',
      balanceCents: 100000,
      createdAt: _now,
      updatedAt: _now,
    ),
  ],
  transactions: txs,
  categories: const [],
  cards: const [],
  installments: const [],
  purchases: const [],
  recurringRules: const [],
  subscriptions: const [],
  settings: const UserSettings(userId: uid, safetyMarginPercent: 10),
);

Transaction tx({
  required String id,
  required TransactionType type,
  required int amount,
  DateTime? comp,
  DateTime? paidAt,
  ExpenseStatus? expenseStatus,
  IncomeStatus? incomeStatus,
  String description = 'Lançamento',
}) {
  final d = comp ?? DateTime(_now.year, _now.month, 15);
  return Transaction(
    id: id,
    userId: uid,
    accountId: 'acc1',
    type: type,
    description: description,
    amountCents: amount,
    competenceDate: d,
    dueDate: d,
    paidAt: paidAt,
    expenseStatus: expenseStatus ?? (paidAt != null ? ExpenseStatus.paid : ExpenseStatus.pending),
    incomeStatus: incomeStatus ?? (paidAt != null ? IncomeStatus.received : IncomeStatus.expected),
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  group('monthOverview', () {
    test('separa pago x pendente e conta as contas em aberto', () {
      final e = engineWith([
        tx(
          id: 'i-paid',
          type: TransactionType.income,
          amount: 500000,
          paidAt: DateTime(_now.year, _now.month, 5),
        ),
        tx(
          id: 'i-pend',
          type: TransactionType.income,
          amount: 200000,
        ),
        tx(
          id: 'e-paid',
          type: TransactionType.expense,
          amount: 100000,
          paidAt: DateTime(_now.year, _now.month, 6),
        ),
        tx(
          id: 'e-pend1',
          type: TransactionType.expense,
          amount: 300000,
        ),
        tx(
          id: 'e-pend2',
          type: TransactionType.expense,
          amount: 50000,
        ),
      ]);

      final o = e.monthOverview(month: _start);
      expect(o.incomePaidCents, 500000);
      expect(o.incomePendingCents, 200000);
      expect(o.expensePaidCents, 100000);
      expect(o.expensePendingCents, 350000);
      expect(o.pendingBillsCount, 2);
      expect(o.paidBillsCount, 1);
      expect(o.hasBills, isTrue);
      expect(o.allBillsPaid, isFalse);
    });

    test('todas as contas pagas → allBillsPaid = true', () {
      final e = engineWith([
        tx(
          id: 'e1',
          type: TransactionType.expense,
          amount: 120000,
          paidAt: DateTime(_now.year, _now.month, 7),
        ),
      ]);
      final o = e.monthOverview(month: _start);
      expect(o.pendingBillsCount, 0);
      expect(o.paidBillsCount, 1);
      expect(o.allBillsPaid, isTrue);
      expect(o.hasBills, isTrue);
    });

    test('transferências não entram no resumo do mês', () {
      final t = tx(
        id: 'tr',
        type: TransactionType.expense,
        amount: 90000,
        paidAt: DateTime(_now.year, _now.month, 8),
      ).copyWith(isTransfer: true);
      final e = engineWith([t]);
      final o = e.monthOverview(month: _start);
      expect(o.expensePaidCents, 0);
      expect(o.expenseTotalCents, 0);
      expect(o.hasBills, isFalse);
    });

    test('valor livre seguro considera receitas previstas do mês', () {
      final e = engineWith([
        tx(id: 'i-pend', type: TransactionType.income, amount: 50000),
        tx(id: 'e-pend', type: TransactionType.expense, amount: 20000),
      ]);
      final o = e.monthOverview(month: _start);
      // 100000 + 50000 − 20000 = 130000; margem 10% → 117000.
      expect(o.safeToSpendCents, 117000);
    });

    test('lançamento de outro mês não afeta o mês corrente', () {
      final other = DateTime(_now.year, _now.month + 3, 10);
      final e = engineWith([
        tx(
          id: 'e-future',
          type: TransactionType.expense,
          amount: 999000,
          comp: other,
        ),
      ]);
      final o = e.monthOverview(month: _start);
      expect(o.expensePendingCents, 0);
      expect(o.pendingBillsCount, 0);
    });
  });
}
