import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ifinance/core/db/collection.dart';
import 'package:ifinance/core/db/hive_db.dart';
import 'package:ifinance/core/finance/finance_engine.dart';
import 'package:ifinance/core/models/models.dart';
import 'package:ifinance/core/services/backup_service.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String uid = 'user-1';

FinanceEngine engineWith({
  List<Transaction> txs = const [],
  List<Account> accounts = const [],
  List<RecurringRule> rules = const [],
  List<CreditCard> cards = const [],
  List<Installment> installments = const [],
}) =>
    FinanceEngine(
      userId: uid,
      accounts: accounts.isNotEmpty
          ? accounts
          : [
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
      cards: cards,
      installments: installments,
      purchases: const [],
      recurringRules: rules,
      subscriptions: const [],
      settings: const UserSettings(userId: uid),
    );

final DateTime _now = DateTime.now();
final DateTime _monthStart = DateTime(_now.year, _now.month, 1);
final DateTime _day10 = DateTime(_now.year, _now.month, 10);

Transaction tx({
  required String id,
  required TransactionType type,
  required int amount,
  DateTime? competence,
  DateTime? due,
  DateTime? paidAt,
  ExpenseStatus? expenseStatus,
  IncomeStatus? incomeStatus,
  String description = 'Lançamento',
  String? creditCardId,
  bool isInvoicePayment = false,
  bool isTransfer = false,
  String? recurringRuleId,
}) =>
    Transaction(
      id: id,
      userId: uid,
      accountId: 'acc1',
      type: type,
      description: description,
      amountCents: amount,
      competenceDate: competence ?? _day10,
      dueDate: due ?? _day10,
      paidAt: paidAt,
      expenseStatus: expenseStatus ?? ExpenseStatus.pending,
      incomeStatus: incomeStatus ?? IncomeStatus.expected,
      creditCardId: creditCardId,
      isInvoicePayment: isInvoicePayment,
      isTransfer: isTransfer,
      recurringRuleId: recurringRuleId,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  group('Cálculos do mês (getMonthlySummary)', () {
    test('despesa cancelada NÃO entra no total', () {
      final e = engineWith(txs: [
        tx(
          id: '1',
          type: TransactionType.expense,
          amount: 10000,
          expenseStatus: ExpenseStatus.paid,
          paidAt: _day10,
        ),
        tx(
          id: '2',
          type: TransactionType.expense,
          amount: 5000,
          expenseStatus: ExpenseStatus.cancelled,
        ),
      ]);
      final s = e.getMonthlySummary(_monthStart);
      expect(s.expenseCents, 10000);
      expect(s.resultCents, -10000);
    });

    test('receita cancelada NÃO entra no total', () {
      final e = engineWith(txs: [
        tx(
          id: '1',
          type: TransactionType.income,
          amount: 30000,
          incomeStatus: IncomeStatus.received,
          paidAt: _day10,
        ),
        tx(
          id: '2',
          type: TransactionType.income,
          amount: 99999,
          incomeStatus: IncomeStatus.cancelled,
        ),
      ]);
      final s = e.getMonthlySummary(_monthStart);
      expect(s.incomeCents, 30000);
    });

    test('transferências têm impacto ZERO no resultado', () {
      final e = engineWith(txs: [
        tx(
          id: '1',
          type: TransactionType.expense,
          amount: 20000,
          isTransfer: true,
          description: 'Transferência (saída)',
          expenseStatus: ExpenseStatus.paid,
          paidAt: _day10,
        ),
        tx(
          id: '2',
          type: TransactionType.income,
          amount: 20000,
          isTransfer: true,
          description: 'Transferência (entrada)',
          incomeStatus: IncomeStatus.received,
          paidAt: _day10,
        ),
      ]);
      final s = e.getMonthlySummary(_monthStart);
      expect(s.incomeCents, 0);
      expect(s.expenseCents, 0);
      expect(s.resultCents, 0);
    });

    test('compra no cartão é despesa econômica; pagamento da fatura NÃO', () {
      final e = engineWith(txs: [
        tx(
          id: '1',
          type: TransactionType.expense,
          amount: 50000,
          creditCardId: 'card1',
          expenseStatus: ExpenseStatus.paid,
          paidAt: _day10,
        ),
        tx(
          id: '2',
          type: TransactionType.expense,
          amount: 50000,
          isInvoicePayment: true,
          expenseStatus: ExpenseStatus.paid,
          paidAt: _day10,
        ),
      ]);
      final s = e.getMonthlySummary(_monthStart);
      // Só a compra conta (não conta em dobro com o pagamento da fatura).
      expect(s.expenseCents, 50000);
    });
  });

  group('Recorrências (sem contagem em dobro)', () {
    RecurringRule rule({int? total}) => RecurringRule(
          id: 'rule1',
          userId: uid,
          description: 'Aluguel',
          type: TransactionType.expense,
          amountCents: 250000,
          accountId: 'acc1',
          frequency: RecurrenceFrequency.monthly,
          startDate: _now,
          totalOccurrences: total,
          preferredDayOfMonth: _now.day,
          createdAt: _now,
          updatedAt: _now,
        );

    test('ocorrência prevista (não lançada) aparece no caixa', () {
      final e = engineWith(rules: [rule(total: 1)]);
      final events = e.cashEvents(
          from: _now, to: _now.add(const Duration(days: 31)));
      final hits = events.where((ev) => ev.label == 'Aluguel').toList();
      expect(hits.length, 1);
      expect(hits.first.amountCents, -250000);
    });

    test('ocorrência JÁ lançada não é contada em dobro', () {
      final e = engineWith(
        rules: [rule(total: 1)],
        txs: [
          tx(
            id: 'manual1',
            type: TransactionType.expense,
            amount: 250000,
            description: 'Aluguel',
            due: _now,
            expenseStatus: ExpenseStatus.paid,
            paidAt: _now,
          ),
        ],
      );
      final events = e.cashEvents(
          from: _now, to: _now.add(const Duration(days: 31)));
      final hits = events.where((ev) => ev.label == 'Aluguel').toList();
      // Só o lançamento manual; a recorrência equivalente é ignorada.
      expect(hits.length, 1);
    });
  });

  group('Transaction.fromMap — dados legados não podem sumir', () {
    test('aceita campos antigos (date/time) quando faltam os novos', () {
      final legacy = {
        'id': 'legacy1',
        'userId': uid,
        'type': 'expense',
        'description': 'Compra antiga',
        'amountCents': 1500,
        'date': _day10.toIso8601String(),
        'time': _day10.toIso8601String(),
        'expenseStatus': 'paid',
        'createdAt': _now.toIso8601String(),
      };
      final t = Transaction.fromMap(legacy);
      expect(t.id, 'legacy1');
      expect(t.amountCents, 1500);
      expect(t.competenceDate.day, _day10.day);
      expect(t.dueDate.day, _day10.day);
    });

    test('tolera tipos inesperados (string/número) sem lançar', () {
      final messy = {
        'id': 'm1',
        'userId': uid,
        'type': 'expense',
        'amountCents': '2500',
        'competenceDate': _day10.toIso8601String(),
        'dueDate': _day10.toIso8601String(),
        'isTransfer': 0,
        'deleted': 'false',
      };
      final t = Transaction.fromMap(messy);
      expect(t.amountCents, 2500);
      expect(t.isTransfer, isFalse);
      expect(t.deleted, isFalse);
    });

    test('sem id lança FormatException (tratado como linha inválida)', () {
      expect(
        () => Transaction.fromMap({'userId': uid, 'type': 'expense'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Collection — resiliência a registro corrompido', () {
    late Directory dir;

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('ifinance_test_');
      Hive.init(dir.path);
      await Hive.openBox<Map>('transactions');
    });

    tearDownAll(() async {
      await Hive.close();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('um item corrompido não derruba a coleção inteira', () async {
      final box = Hive.box<Map>('transactions');
      await box.clear();
      await box.put('ok', tx(
        id: 'ok',
        type: TransactionType.expense,
        amount: 1000,
      ).toMap());
      // Linha inválida (sem id) — deve ser ignorada, não explodir.
      await box.put('bad', <String, dynamic>{'foo': 'bar'});

      final col = Collection<Transaction>(
        boxName: 'transactions',
        fromMap: Transaction.fromMap,
        toMap: (t) => t.toMap(),
        idOf: (t) => t.id,
        userIdOf: (t) => t.userId,
      );

      final all = col.all();
      expect(all.length, 1);
      expect(all.first.id, 'ok');
      expect(Collection.droppedCounts['transactions'], greaterThan(0));
    });
  });

  group('BackupService — snapshots automáticos', () {
    late Directory dir;
    const userId = 'backup-user';

    Map<String, dynamic> sampleData(int n) => {
          'user': {'id': userId, 'name': 'T'},
          'accounts': [
            for (var i = 0; i < n; i++)
              {'id': 'a$i', 'userId': userId, 'balanceCents': 1000},
          ],
          'transactions': [
            for (var i = 0; i < n; i++) {'id': 't$i', 'userId': userId},
          ],
        };

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('ifinance_backup_');
      Hive.init(dir.path);
      await Hive.openBox<Map>(Db.backups);
    });

    tearDownAll(() async {
      await Hive.close();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    setUp(() async {
      await Hive.box<Map>(Db.backups).clear();
    });

    test('cria, lista e lê um snapshot', () async {
      final id = await BackupService.snapshotNow(
        userId: userId,
        data: sampleData(3),
        reason: 'auto',
      );
      expect(id, isNotNull);

      final list = BackupService.listFor(userId);
      expect(list.length, 1);
      expect(list.first.reason, 'auto');

      final read = BackupService.read(id!);
      expect(read, isNotNull);
      expect((read!['accounts'] as List).length, 3);
    });

    test('não grava snapshot idêntico (dedupe)', () async {
      final first = await BackupService.snapshotNow(
        userId: userId,
        data: sampleData(2),
        reason: 'auto',
      );
      expect(first, isNotNull);
      final again = await BackupService.snapshotNow(
        userId: userId,
        data: sampleData(2),
        reason: 'auto',
      );
      expect(again, isNull); // conteúdo igual → ignorado
      expect(BackupService.listFor(userId).length, 1);
    });

    test('base vazia é ignorada (não sobrescreve dados bons)', () async {
      final id = await BackupService.snapshotNow(
        userId: userId,
        data: {'user': {'id': userId}, 'accounts': const []},
        reason: 'auto',
      );
      expect(id, isNull);
      expect(BackupService.listFor(userId), isEmpty);
    });

    test('rotaciona mantendo no máximo ${BackupService.maxSnapshots}', () async {
      for (var i = 1; i <= BackupService.maxSnapshots + 3; i++) {
        await BackupService.snapshotNow(
          userId: userId,
          data: sampleData(i),
          reason: 'auto',
        );
      }
      expect(
          BackupService.listFor(userId).length, BackupService.maxSnapshots);
    });

    test('clearFor remove os snapshots do usuário', () async {
      await BackupService.snapshotNow(
          userId: userId, data: sampleData(1), reason: 'auto');
      await BackupService.clearFor(userId);
      expect(BackupService.listFor(userId), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Restauração de backup completo (recriação de conta) — cap. 42/73
  // ---------------------------------------------------------------------------
  group('Restauração de backup (recria usuário + dados)', () {
    test('copyWith permite trocar o id (remap por e-mail)', () {
      final now = DateTime.now();
      final u = AppUser(
        id: 'novo-id',
        name: 'Ivney',
        email: 'ivney@test.com',
        passwordHash: 'h',
        passwordSalt: 's',
        createdAt: now,
        updatedAt: now,
      );
      final remapped = u.copyWith(id: 'id-existente');
      expect(remapped.id, 'id-existente');
      expect(remapped.email, 'ivney@test.com');
      expect(remapped.name, 'Ivney');
    });

    test('toMap/fromMap preserva os campos essenciais do usuário', () {
      final now = DateTime.now();
      final u = AppUser(
        id: 'u1',
        name: 'Ivney',
        email: 'ivney@test.com',
        passwordHash: 'hash',
        passwordSalt: 'salt',
        emailVerified: true,
        onboardingCompleted: true,
        createdAt: now,
        updatedAt: now,
      );
      final back = AppUser.fromMap(u.toMap());
      expect(back.id, u.id);
      expect(back.email, u.email);
      expect(back.passwordHash, u.passwordHash);
      expect(back.passwordSalt, u.passwordSalt);
      expect(back.onboardingCompleted, isTrue);
    });
  });
}
