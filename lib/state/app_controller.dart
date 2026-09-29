import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db/hive_db.dart';
import '../core/db/repository.dart';
import '../core/db/collection.dart';
import '../core/finance/finance_engine.dart';
import '../core/models/models.dart';
import '../core/services/auth_service.dart';
import '../core/services/seed_service.dart';
import '../core/services/statement_importer.dart';
import '../core/utils/category_icons.dart';
import '../core/utils/date_helpers.dart';
import '../core/utils/money.dart';

/// Controlador central de estado do aplicativo.
/// Mantém a sessão, as coleções do usuário e expõe o FinanceEngine.
/// Toda a lógica de negócio de gravação passa por aqui (serviços), nunca
/// diretamente na UI (cap. 56).
class AppController extends ChangeNotifier {
  final Repository repo = Repository();
  late final AuthService auth = AuthService(repo);

  bool _bootstrapped = false;
  bool _loading = true;

  AppUser? _user;
  UserSettings _settings = const UserSettings(userId: '');
  AppThemeMode _themeMode = AppThemeMode.system;

  // Coleções do usuário atual
  List<Account> accounts = [];
  List<Category> categories = [];
  List<Transaction> transactions = [];
  List<CreditCard> cards = [];
  List<CardPurchase> purchases = [];
  List<Installment> installments = [];
  List<RecurringRule> recurringRules = [];
  List<Subscription> subscriptions = [];
  List<Budget> budgets = [];
  List<Goal> goals = [];
  List<GoalContribution> contributions = [];
  List<Asset> assets = [];
  List<Liability> liabilities = [];
  List<AppNotification> notifications = [];

  bool get loading => _loading;
  bool get bootstrapped => _bootstrapped;
  bool get isAuthenticated => _user != null;
  AppUser? get user => _user;
  UserSettings get settings => _settings;
  AppThemeMode get themeMode => _themeMode;

  static const _sessionKey = 'ifinance_session_user';

  /// Motor financeiro do usuário atual.
  FinanceEngine get engine => FinanceEngine(
        userId: _user?.id ?? '',
        accounts: accounts,
        transactions: transactions,
        categories: categories,
        cards: cards,
        installments: installments,
        purchases: purchases,
        recurringRules: recurringRules,
        subscriptions: subscriptions,
        settings: _settings,
      );

  // ---------------------------------------------------------------------------
  // Bootstrap / sessão
  // ---------------------------------------------------------------------------

  Future<void> bootstrap() async {
    _loading = true;
    notifyListeners();
    await Db.init();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_sessionKey);
    if (userId != null) {
      final existing = repo.users.findById(userId);
      if (existing != null && !existing.deleted) {
        auth.restoreSession(userId);
        _user = auth.currentUser;
        await _loadUserData();
      }
    }
    _bootstrapped = true;
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    final uid = _user!.id;
    final loadedSettings = repo.settings.findById(uid);
    _settings = loadedSettings ?? UserSettings(userId: uid);
    if (loadedSettings == null) {
      await repo.settings.put(_settings);
    }
    _themeMode = _settings.themeMode;
    Money.setSymbol(_symbolFor(_settings.currency));

    accounts = repo.accounts.byUser(uid);
    categories = repo.categories.byUser(uid);
    transactions = repo.transactions.byUser(uid);
    cards = repo.cards.byUser(uid);
    purchases = repo.purchases.byUser(uid);
    installments = repo.installments.byUser(uid);
    recurringRules = repo.recurring.byUser(uid);
    subscriptions = repo.subscriptions.byUser(uid);
    budgets = repo.budgets.byUser(uid);
    goals = repo.goals.byUser(uid);
    contributions = repo.contributions.byUser(uid);
    assets = repo.assets.byUser(uid);
    liabilities = repo.liabilities.byUser(uid);
    notifications = repo.notifications.byUser(uid);
  }

  Future<void> _persistSession(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, userId);
    }
  }

  Future<void> refresh() async {
    if (_user == null) return;
    await _loadUserData();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Autenticação
  // ---------------------------------------------------------------------------

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = await auth.register(name: name, email: email, password: password);
    _user = user;
    await _persistSession(user.id);
    await _seedDefaultCategories();
    await _loadUserData();
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final user = await auth.login(email: email, password: password);
    _user = user;
    await _persistSession(user.id);
    await _loadUserData();
    notifyListeners();
  }

  /// Entra com a conta de demonstração, criando dados de exemplo se necessário.
  Future<void> loginDemo() async {
    const demoEmail = 'demo@ifinance.app';
    const demoPassword = 'ifinance123';
    if (!auth.emailExists(demoEmail)) {
      final user = await auth.register(
        name: 'Usuário Demo',
        email: demoEmail,
        password: demoPassword,
      );
      _user = user;
      await _persistSession(user.id);
      await SeedService(repo).seedDemo(user.id);
      await auth.completeOnboarding();
      _user = auth.currentUser;
    } else {
      await login(email: demoEmail, password: demoPassword);
      return;
    }
    await _loadUserData();
    notifyListeners();
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await auth.resetPassword(email: email, newPassword: newPassword);
  }

  Future<void> logout() async {
    auth.logout();
    _user = null;
    _settings = const UserSettings(userId: '');
    accounts = [];
    categories = [];
    transactions = [];
    cards = [];
    purchases = [];
    installments = [];
    recurringRules = [];
    subscriptions = [];
    budgets = [];
    goals = [];
    contributions = [];
    assets = [];
    liabilities = [];
    notifications = [];
    await _persistSession(null);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await auth.deleteAccount();
    _user = null;
    await _persistSession(null);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await auth.completeOnboarding();
    _user = auth.currentUser;
    notifyListeners();
  }

  Future<void> verifyEmailNow() async {
    await auth.verifyEmail();
    _user = auth.currentUser;
    notifyListeners();
  }

  Future<void> _seedDefaultCategories() async {
    final uid = _user!.id;
    final now = DateTime.now();
    final list = CategoryIcons.defaults
        .map((d) => Category(
              id: repo.newId(),
              userId: uid,
              name: d.name,
              iconName: d.icon,
              colorValue: d.color,
              isIncome: d.isIncome,
              createdAt: now,
            ))
        .toList();
    await repo.categories.putAll(list);
  }

  Category? categoryById(String? id) {
    if (id == null) return null;
    final m = categories.where((c) => c.id == id);
    return m.isEmpty ? null : m.first;
  }

  Account? accountById(String? id) {
    if (id == null) return null;
    final m = accounts.where((a) => a.id == id);
    return m.isEmpty ? null : m.first;
  }

  CreditCard? cardById(String? id) {
    if (id == null) return null;
    final m = cards.where((c) => c.id == id);
    return m.isEmpty ? null : m.first;
  }

  // ---------------------------------------------------------------------------
  // Tema e preferências
  // ---------------------------------------------------------------------------

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    _settings = _settings.copyWith(themeMode: mode);
    if (_user != null) await repo.settings.put(_settings);
    notifyListeners();
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    Money.setSymbol(_symbolFor(newSettings.currency));
    if (_user != null) await repo.settings.put(_settings);
    notifyListeners();
  }

  static String _symbolFor(String currency) => switch (currency) {
        'USD' => 'US\$',
        'EUR' => '€',
        _ => 'R\$',
      };

  // ---------------------------------------------------------------------------
  // Contas
  // ---------------------------------------------------------------------------

  Future<void> saveAccount(Account account) async {
    await repo.accounts.put(account);
    await repo.log(_user!.id, 'save', 'Account',
        entityId: account.id, details: account.name);
    await refresh();
  }

  Future<void> archiveAccount(Account account) async {
    await repo.accounts.put(account.copyWith(archived: true));
    await repo.log(_user!.id, 'archive', 'Account', entityId: account.id);
    await refresh();
  }

  /// Ajuste de saldo (cap. 70) — gera movimentação de ajuste, nunca altera
  /// o histórico silenciosamente.
  Future<void> adjustBalance(Account account, int newBalanceCents) async {
    final diff = newBalanceCents - account.balanceCents;
    if (diff == 0) return;
    final now = DateTime.now();
    final tx = Transaction(
      id: repo.newId(),
      userId: _user!.id,
      accountId: account.id,
      type: TransactionType.adjustment,
      description: 'Ajuste de saldo',
      amountCents: diff.abs(),
      competenceDate: now,
      dueDate: now,
      paidAt: now,
      paymentMethod: PaymentMethod.other,
      notes: 'Ajuste manual de conciliação',
      createdAt: now,
      updatedAt: now,
    );
    // Ajuste positivo = entrada; negativo = saída. Guardamos o valor assinado
    // via tipo (adjustment) e aplicamos o efeito no saldo da conta.
    await repo.accounts.put(account.copyWith(
      balanceCents: newBalanceCents,
      updatedAt: now,
    ));
    await repo.transactions.put(tx);
    await repo.log(_user!.id, 'adjust_balance', 'Account',
        entityId: account.id, details: 'diff=$diff');
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Categorias
  // ---------------------------------------------------------------------------

  Future<void> saveCategory(Category category) async {
    await repo.categories.put(category);
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Movimentações
  // ---------------------------------------------------------------------------

  Future<void> saveTransaction(Transaction tx) async {
    await repo.transactions.put(tx);
    await _applyAccountEffect(tx, reverse: false);
    await refresh();
  }

  /// Atualiza uma movimentação já existente revertendo o efeito antigo.
  Future<void> updateTransaction(Transaction oldTx, Transaction newTx) async {
    await _applyAccountEffect(oldTx, reverse: true);
    await repo.transactions.put(newTx);
    await _applyAccountEffect(newTx, reverse: false);
    await refresh();
  }

  Future<void> markTransactionPaid(Transaction tx, {bool paid = true}) async {
    final now = DateTime.now();
    final updated = tx.copyWith(
      paidAt: paid ? now : null,
      clearPaidAt: !paid,
      expenseStatus: tx.isExpense
          ? (paid ? ExpenseStatus.paid : ExpenseStatus.pending)
          : tx.expenseStatus,
      incomeStatus: tx.isIncome
          ? (paid ? IncomeStatus.received : IncomeStatus.expected)
          : tx.incomeStatus,
      updatedAt: now,
    );
    await _applyAccountEffect(tx, reverse: true);
    await repo.transactions.put(updated);
    await _applyAccountEffect(updated, reverse: false);
    await refresh();
  }

  Future<void> cancelTransaction(Transaction tx) async {
    final updated = tx.copyWith(
      expenseStatus: ExpenseStatus.cancelled,
      incomeStatus: IncomeStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    await _applyAccountEffect(tx, reverse: true);
    await repo.transactions.put(updated);
    await repo.log(_user!.id, 'cancel', 'Transaction', entityId: tx.id);
    await refresh();
  }

  Future<void> deleteTransaction(Transaction tx) async {
    await _applyAccountEffect(tx, reverse: true);
    await repo.transactions.delete(tx.id);
    await repo.log(_user!.id, 'delete', 'Transaction', entityId: tx.id);
    await refresh();
  }

  /// Aplica (ou reverte) o efeito de uma movimentação no saldo da conta.
  /// Compras de cartão NÃO alteram o saldo da conta (cap. 20).
  Future<void> _applyAccountEffect(Transaction tx, {required bool reverse}) async {
    if (tx.accountId == null) return;
    if (!tx.affectsCash) return;
    if (!tx.isPaid) return;

    final account = accountById(tx.accountId);
    if (account == null) return;

    final sign = (tx.isIncome ? 1 : -1) * (reverse ? -1 : 1);
    final delta = tx.amountCents * sign;
    await repo.accounts.put(account.copyWith(
      balanceCents: account.balanceCents + delta,
      updatedAt: DateTime.now(),
    ));
  }

  /// Cria despesa comum.
  Future<void> addExpense({
    required String description,
    required int amountCents,
    required String accountId,
    String? categoryId,
    DateTime? date,
    PaymentMethod method = PaymentMethod.other,
    bool paid = true,
    String notes = '',
    String? creditCardId,
  }) async {
    final now = DateTime.now();
    final d = date ?? now;
    final tx = Transaction(
      id: repo.newId(),
      userId: _user!.id,
      accountId: creditCardId == null ? accountId : null,
      categoryId: categoryId,
      creditCardId: creditCardId,
      type: TransactionType.expense,
      description: description,
      amountCents: amountCents,
      competenceDate: d,
      dueDate: d,
      paidAt: paid && creditCardId == null ? d : null,
      expenseStatus: paid
          ? ExpenseStatus.paid
          : ExpenseStatus.pending,
      paymentMethod: method,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await saveTransaction(tx);
  }

  /// Cria receita.
  Future<void> addIncome({
    required String description,
    required int amountCents,
    required String accountId,
    String? categoryId,
    DateTime? date,
    bool received = true,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final d = date ?? now;
    final tx = Transaction(
      id: repo.newId(),
      userId: _user!.id,
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.income,
      description: description,
      amountCents: amountCents,
      competenceDate: d,
      dueDate: d,
      paidAt: received ? d : null,
      incomeStatus: received ? IncomeStatus.received : IncomeStatus.expected,
      paymentMethod: PaymentMethod.other,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await saveTransaction(tx);
  }

  /// Transferência entre contas próprias (cap. 17): duas movimentações
  /// vinculadas, impacto zero no resultado consolidado.
  Future<void> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    String description = 'Transferência',
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final d = date ?? now;
    final groupId = repo.newId();

    final out = Transaction(
      id: repo.newId(),
      userId: _user!.id,
      accountId: fromAccountId,
      type: TransactionType.expense,
      description: description,
      amountCents: amountCents,
      competenceDate: d,
      dueDate: d,
      paidAt: d,
      expenseStatus: ExpenseStatus.paid,
      paymentMethod: PaymentMethod.transfer,
      isTransfer: true,
      transferGroupId: groupId,
      createdAt: now,
      updatedAt: now,
    );
    final inbox = Transaction(
      id: repo.newId(),
      userId: _user!.id,
      accountId: toAccountId,
      type: TransactionType.income,
      description: description,
      amountCents: amountCents,
      competenceDate: d,
      dueDate: d,
      paidAt: d,
      incomeStatus: IncomeStatus.received,
      paymentMethod: PaymentMethod.transfer,
      isTransfer: true,
      transferGroupId: groupId,
      createdAt: now,
      updatedAt: now,
    );

    await repo.transactions.putAll([out, inbox]);
    // Efeito líquido nas contas (não usa _applyAccountEffect para evitar dupla
    // contagem, pois transferência tem tratamento próprio).
    final from = accountById(fromAccountId);
    final to = accountById(toAccountId);
    if (from != null) {
      await repo.accounts.put(from.copyWith(
        balanceCents: from.balanceCents - amountCents,
        updatedAt: now,
      ));
    }
    if (to != null) {
      await repo.accounts.put(to.copyWith(
        balanceCents: to.balanceCents + amountCents,
        updatedAt: now,
      ));
    }
    await repo.log(_user!.id, 'transfer', 'Transfer', details: '$amountCents');
    await refresh();
  }

  /// Exclui as duas pernas de uma transferência, revertendo o efeito nas contas.
  Future<void> deleteTransfer(Transaction leg) async {
    final groupId = leg.transferGroupId;
    if (groupId == null) {
      await deleteTransaction(leg);
      return;
    }
    final legs =
        transactions.where((t) => t.transferGroupId == groupId).toList();
    final now = DateTime.now();
    for (final t in legs) {
      final acc = accountById(t.accountId);
      if (acc != null) {
        // Reverte: a perna de saída devolve, a de entrada retira.
        final sign = t.isIncome ? -1 : 1;
        await repo.accounts.put(acc.copyWith(
          balanceCents: acc.balanceCents + t.amountCents * sign,
          updatedAt: now,
        ));
      }
      await repo.transactions.delete(t.id);
    }
    await repo.log(_user!.id, 'transfer_delete', 'Transfer', entityId: groupId);
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Cartões e compras
  // ---------------------------------------------------------------------------

  Future<void> saveCard(CreditCard card) async {
    await repo.cards.put(card);
    await refresh();
  }

  Future<void> deleteCard(CreditCard card) async {
    await repo.cards.put(card.copyWith(archived: true));
    await refresh();
  }

  /// Compra no cartão (cap. 20/21). Se parcelada, cria a compra original e as
  /// parcelas, cada uma vinculada ao mês de referência da fatura.
  Future<void> addCardPurchase({
    required String creditCardId,
    required String description,
    required int totalCents,
    required int installmentsCount,
    String? categoryId,
    DateTime? purchaseDate,
  }) async {
    final card = cardById(creditCardId);
    if (card == null) return;
    await _insertPurchase(
      creditCardId: creditCardId,
      description: description,
      totalCents: totalCents,
      installmentsCount: installmentsCount,
      categoryId: categoryId,
      purchaseDate: purchaseDate ?? DateTime.now(),
    );
    await repo.log(_user!.id, 'card_purchase', 'CardPurchase',
        details: '$totalCents x$installmentsCount');
    await refresh();
  }

  /// Insere a compra original e suas transações/parcelas.
  Future<void> _insertPurchase({
    required String creditCardId,
    required String description,
    required int totalCents,
    required int installmentsCount,
    String? categoryId,
    required DateTime purchaseDate,
  }) async {
    final now = DateTime.now();
    final pDate = purchaseDate;

    final purchase = CardPurchase(
      id: repo.newId(),
      userId: _user!.id,
      creditCardId: creditCardId,
      categoryId: categoryId,
      description: description,
      totalCents: totalCents,
      installmentsCount: installmentsCount,
      firstReferenceMonth: DateTime(pDate.year, pDate.month, 1),
      createdAt: now,
    );
    await repo.purchases.put(purchase);

    final amounts = _split(totalCents, installmentsCount);

    if (installmentsCount <= 1) {
      // Compra à vista: cria uma transação econômica no cartão.
      final tx = Transaction(
        id: repo.newId(),
        userId: _user!.id,
        creditCardId: creditCardId,
        categoryId: categoryId,
        type: TransactionType.expense,
        description: description,
        amountCents: totalCents,
        competenceDate: pDate,
        dueDate: pDate,
        paymentMethod: PaymentMethod.credit,
        purchaseId: purchase.id,
        createdAt: now,
        updatedAt: now,
      );
      await repo.transactions.put(tx);
    } else {
      final list = <Installment>[];
      for (var i = 0; i < installmentsCount; i++) {
        final ref = DateTime(pDate.year, pDate.month + i, 1);
        list.add(Installment(
          id: repo.newId(),
          userId: _user!.id,
          purchaseId: purchase.id,
          creditCardId: creditCardId,
          number: i + 1,
          totalCount: installmentsCount,
          amountCents: amounts[i],
          referenceMonth: ref,
          createdAt: now,
        ));
        // Também cria transação de competência para o mês da parcela.
        await repo.transactions.put(Transaction(
          id: repo.newId(),
          userId: _user!.id,
          creditCardId: creditCardId,
          categoryId: categoryId,
          type: TransactionType.expense,
          description: '$description (${i + 1}/$installmentsCount)',
          amountCents: amounts[i],
          competenceDate: ref,
          dueDate: ref,
          paymentMethod: PaymentMethod.credit,
          purchaseId: purchase.id,
          createdAt: now,
          updatedAt: now,
        ));
      }
      await repo.installments.putAll(list);
    }
  }

  /// Remove todas as transações e parcelas de uma compra.
  Future<void> _removePurchaseData(String purchaseId) async {
    final txs = transactions.where((t) => t.purchaseId == purchaseId).toList();
    for (final t in txs) {
      await repo.transactions.delete(t.id);
    }
    final insts =
        installments.where((i) => i.purchaseId == purchaseId).toList();
    for (final i in insts) {
      await repo.installments.delete(i.id);
    }
  }

  /// Edita uma compra no cartão (reconstrói transações e parcelas).
  Future<void> updateCardPurchase({
    required CardPurchase purchase,
    required int totalCents,
    required int installmentsCount,
    String? categoryId,
    String? creditCardId,
    String? description,
    DateTime? purchaseDate,
  }) async {
    await _removePurchaseData(purchase.id);
    await repo.purchases.delete(purchase.id);
    await _insertPurchase(
      creditCardId: creditCardId ?? purchase.creditCardId,
      description: description ?? purchase.description,
      totalCents: totalCents,
      installmentsCount: installmentsCount,
      categoryId: categoryId,
      purchaseDate: purchaseDate ?? purchase.firstReferenceMonth,
    );
    await repo.log(_user!.id, 'card_purchase_update', 'CardPurchase',
        entityId: purchase.id);
    await refresh();
  }

  /// Exclui uma compra no cartão (e suas transações/parcelas).
  Future<void> deletePurchase(CardPurchase purchase) async {
    await _removePurchaseData(purchase.id);
    await repo.purchases.delete(purchase.id);
    await repo.log(_user!.id, 'card_purchase_delete', 'CardPurchase',
        entityId: purchase.id);
    await refresh();
  }

  static List<int> _split(int total, int n) {
    if (n <= 0) return const [];
    final base = total ~/ n;
    final rem = total - base * n;
    return List<int>.generate(n, (i) => base + (i < rem ? 1 : 0));
  }

  /// Paga a fatura de um cartão — movimentação de caixa (cap. 20).
  Future<void> payInvoice({
    required CreditCard card,
    required DateTime referenceMonth,
    required int totalCents,
    required String accountId,
  }) async {
    final now = DateTime.now();
    final refStart = DateTime(referenceMonth.year, referenceMonth.month, 1);
    final tx = Transaction(
      id: repo.newId(),
      userId: _user!.id,
      accountId: accountId,
      creditCardId: card.id,
      type: TransactionType.expense,
      description: 'Pagamento fatura ${card.name}',
      amountCents: totalCents,
      competenceDate: now,
      dueDate: now,
      paidAt: now,
      expenseStatus: ExpenseStatus.paid,
      paymentMethod: PaymentMethod.transfer,
      isInvoicePayment: true,
      invoiceReferenceMonth: refStart,
      createdAt: now,
      updatedAt: now,
    );
    await repo.transactions.put(tx);
    // Debita a conta.
    final acc = accountById(accountId);
    if (acc != null) {
      await repo.accounts.put(acc.copyWith(
        balanceCents: acc.balanceCents - totalCents,
        updatedAt: now,
      ));
    }
    // Marca as parcelas do mês como pagas.
    final monthInst = installments.where((i) =>
        i.creditCardId == card.id &&
        DateTime(i.referenceMonth.year, i.referenceMonth.month, 1) == refStart);
    for (final inst in monthInst) {
      await repo.installments.put(inst.copyWith(paid: true));
    }
    await repo.log(_user!.id, 'pay_invoice', 'Invoice',
        entityId: card.id, details: '$totalCents');
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Recorrências
  // ---------------------------------------------------------------------------

  Future<void> saveRecurring(RecurringRule rule) async {
    await repo.recurring.put(rule);
    await refresh();
  }

  Future<void> toggleRecurring(RecurringRule rule) async {
    await repo.recurring.put(rule.copyWith(active: !rule.active));
    await refresh();
  }

  Future<void> deleteRecurring(RecurringRule rule) async {
    await repo.recurring.delete(rule.id);
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Orçamentos
  // ---------------------------------------------------------------------------

  Future<void> saveBudget(Budget budget) async {
    await repo.budgets.put(budget);
    await refresh();
  }

  Future<void> deleteBudget(Budget budget) async {
    await repo.budgets.delete(budget.id);
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Metas
  // ---------------------------------------------------------------------------

  Future<void> saveGoal(Goal goal) async {
    await repo.goals.put(goal);
    await refresh();
  }

  Future<void> contributeToGoal(Goal goal, int amountCents, {String note = ''}) async {
    final now = DateTime.now();
    await repo.contributions.put(GoalContribution(
      id: repo.newId(),
      userId: _user!.id,
      goalId: goal.id,
      amountCents: amountCents,
      date: now,
      note: note,
    ));
    await repo.goals.put(goal.copyWith(
      accumulatedCents: goal.accumulatedCents + amountCents,
      updatedAt: now,
    ));
    await refresh();
  }

  Future<void> deleteGoal(Goal goal) async {
    await repo.goals.put(goal.copyWith(archived: true));
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Patrimônio e dívidas
  // ---------------------------------------------------------------------------

  Future<void> saveAsset(Asset asset) async {
    await repo.assets.put(asset);
    await refresh();
  }

  Future<void> deleteAsset(Asset asset) async {
    await repo.assets.delete(asset.id);
    await refresh();
  }

  Future<void> saveLiability(Liability liability) async {
    await repo.liabilities.put(liability);
    await refresh();
  }

  Future<void> deleteLiability(Liability liability) async {
    await repo.liabilities.put(liability.copyWith(archived: true));
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Assinaturas
  // ---------------------------------------------------------------------------

  Future<void> saveSubscription(Subscription sub) async {
    await repo.subscriptions.put(sub);
    await refresh();
  }

  Future<void> toggleSubscription(Subscription sub) async {
    await repo.subscriptions.put(sub.copyWith(active: !sub.active));
    await refresh();
  }

  Future<void> deleteSubscription(Subscription sub) async {
    await repo.subscriptions.delete(sub.id);
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Simulações
  // ---------------------------------------------------------------------------

  Future<void> saveSimulation(Simulation sim) async {
    await repo.simulations.put(sim);
    await refresh();
  }

  Future<void> deleteSimulation(Simulation sim) async {
    await repo.simulations.delete(sim.id);
    await refresh();
  }

  List<Simulation> get simulations => repo.simulations.byUser(_user?.id ?? '');

  // ---------------------------------------------------------------------------
  // Notificações
  // ---------------------------------------------------------------------------

  Future<void> addNotification(AppNotification n) async {
    await repo.notifications.put(n);
    await refresh();
  }

  Future<void> markNotificationRead(AppNotification n) async {
    await repo.notifications.put(n.copyWith(read: true));
    await refresh();
  }

  int get unreadNotifications => notifications.where((n) => !n.read).length;

  /// Gera notificações a partir dos insights atuais (cap. 41).
  Future<void> syncNotifications() async {
    final uid = _user?.id;
    if (uid == null) return;
    final radar = engine.getRadar();
    final now = DateTime.now();
    final existingTitles = notifications
        .where((n) => DateUtils.isSameDay(n.date, now))
        .map((n) => n.title)
        .toSet();
    var changed = false;
    for (final insight in radar.insights) {
      if (existingTitles.contains(insight.title)) continue;
      await repo.notifications.put(AppNotification(
        id: repo.newId(),
        userId: uid,
        title: insight.title,
        message: insight.message,
        severity: insight.severity,
        date: now,
      ));
      changed = true;
    }
    if (changed) await refresh();
  }

  // ---------------------------------------------------------------------------
  // Exportação / Backup / Restauração (cap. 42/43)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _snapshot() => {
        'user': _user?.toMap(),
        'settings': _settings.toMap(),
        'accounts': accounts.map((e) => e.toMap()).toList(),
        'categories': categories.map((e) => e.toMap()).toList(),
        'transactions': transactions.map((e) => e.toMap()).toList(),
        'cards': cards.map((e) => e.toMap()).toList(),
        'purchases': purchases.map((e) => e.toMap()).toList(),
        'installments': installments.map((e) => e.toMap()).toList(),
        'recurringRules': recurringRules.map((e) => e.toMap()).toList(),
        'subscriptions': subscriptions.map((e) => e.toMap()).toList(),
        'budgets': budgets.map((e) => e.toMap()).toList(),
        'goals': goals.map((e) => e.toMap()).toList(),
        'contributions': contributions.map((e) => e.toMap()).toList(),
        'assets': assets.map((e) => e.toMap()).toList(),
        'liabilities': liabilities.map((e) => e.toMap()).toList(),
        'notifications': notifications.map((e) => e.toMap()).toList(),
      };

  /// Backup completo (JSON) — inclui todas as coleções + metadados.
  Map<String, dynamic> exportBackup() => {
        'app': 'IFinance',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': _snapshot(),
      };

  /// Exporta o backup como texto JSON.
  String exportBackupJson() =>
      const JsonEncoder.withIndent('  ').convert(exportBackup());

  /// Exporta as movimentações em CSV (pt-BR, separador ';').
  String exportTransactionsCsv() {
    final b = StringBuffer();
    b.writeln('Data;Tipo;Descricao;Categoria;Conta;Cartao;Valor;Status');
    for (final t in transactions) {
      if (t.isTransfer) continue;
      final cat = categoryById(t.categoryId)?.name ?? '';
      final acc = accountById(t.accountId)?.name ?? '';
      final card = cardById(t.creditCardId)?.name ?? '';
      final tipo = t.isInvoicePayment
          ? 'Fatura'
          : (t.isIncome ? 'Receita' : 'Despesa');
      final valor =
          '${t.isIncome ? '' : '-'}${(t.amountCents / 100).toStringAsFixed(2)}';
      b.writeln([
        DateHelpers.isoDate(t.competenceDate),
        tipo,
        _csvEscape(t.description),
        _csvEscape(cat),
        _csvEscape(acc),
        _csvEscape(card),
        valor.replaceAll('.', ','),
        t.isPaid ? 'Concluido' : 'Pendente',
      ].join(';'));
    }
    return b.toString();
  }

  String _csvEscape(String s) =>
      s.contains(';') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;

  /// Importa lançamentos de um extrato (CSV/OFX) para uma conta.
  /// Retorna quantos lançamentos foram criados.
  Future<int> importStatements({
    required List<ImportedRow> rows,
    required String accountId,
    bool asPending = false,
    bool autoCategory = true,
  }) async {
    final uid = _user!.id;
    final now = DateTime.now();
    var count = 0;
    for (final r in rows) {
      final isIncome = r.amountCents > 0;
      final abs = r.amountCents.abs();
      if (abs == 0) continue;
      final catId = autoCategory
          ? _bestCategoryFor(r.description, isIncome)
          : null;
      final tx = Transaction(
        id: repo.newId(),
        userId: uid,
        accountId: accountId,
        categoryId: catId,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        description: r.description,
        amountCents: abs,
        competenceDate: r.date,
        dueDate: r.date,
        paidAt: asPending ? null : r.date,
        expenseStatus: isIncome
            ? ExpenseStatus.pending
            : (asPending ? ExpenseStatus.pending : ExpenseStatus.paid),
        incomeStatus: isIncome
            ? (asPending ? IncomeStatus.expected : IncomeStatus.received)
            : IncomeStatus.expected,
        paymentMethod: PaymentMethod.other,
        notes: 'Importado de extrato',
        createdAt: now,
        updatedAt: now,
      );
      await saveTransaction(tx);
      count++;
    }
    await repo.log(uid, 'import', 'Statement', details: '$count lançamentos');
    await refresh();
    return count;
  }

  /// Heurística simples de categorização por palavra-chave na descrição.
  String? _bestCategoryFor(String description, bool isIncome) {
    final d = _stripAccents(description.toLowerCase());
    for (final c in categories.where((c) => c.isIncome == isIncome)) {
      final name = _stripAccents(c.name.toLowerCase());
      if (name.length >= 3 && d.contains(name)) return c.id;
    }
    final map = <String, List<String>>{
      'aliment': ['mercado', 'supermerc', 'padaria', 'restaurante', 'lanchonete', 'ifood'],
      'transport': ['uber', '99', 'posto', 'combust', 'gasolina', 'estacionamento', 'metro'],
      'moradia': ['aluguel', 'condominio', 'luz', 'energia', 'agua', 'internet'],
      'saude': ['farmacia', 'farmácia', 'drogaria', 'hospital', 'clinica', 'plano de saude'],
      'lazer': ['cinema', 'netflix', 'spotify', 'streaming', 'show'],
      'educacao': ['escola', 'faculdade', 'curso', 'livraria'],
      'salario': ['salario', 'salário', 'pagamento', 'vencimento', 'proventos'],
    };
    for (final entry in map.entries) {
      if (entry.value.any((k) => d.contains(_stripAccents(k)))) {
        final match = categories.where((c) =>
            c.isIncome == isIncome &&
            _stripAccents(c.name.toLowerCase()).contains(entry.key));
        if (match.isNotEmpty) return match.first.id;
      }
    }
    return null;
  }

  static String _stripAccents(String s) => s
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');

  /// Restaura um backup (substitui os dados do usuário atual).
  Future<int> restoreBackup(Map<String, dynamic> json) async {
    final uid = _user!.id;
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    int count = 0;

    // Limpa coleções atuais do usuário.
    for (final box in [
      repo.accounts,
      repo.categories,
      repo.transactions,
      repo.cards,
      repo.purchases,
      repo.installments,
      repo.recurring,
      repo.subscriptions,
      repo.budgets,
      repo.goals,
      repo.contributions,
      repo.assets,
      repo.liabilities,
      repo.notifications,
    ]) {
      await box.clearUser(uid);
    }

    Future<void> load<T>(
      String key,
      Collection<T> col,
      T Function(Map<String, dynamic>) fromMap,
    ) async {
      final list = (data[key] as List?) ?? const [];
      for (final raw in list) {
        await col.put(fromMap(Map<String, dynamic>.from(raw as Map)));
        count++;
      }
    }

    await load('accounts', repo.accounts, Account.fromMap);
    await load('categories', repo.categories, Category.fromMap);
    await load('transactions', repo.transactions, Transaction.fromMap);
    await load('cards', repo.cards, CreditCard.fromMap);
    await load('purchases', repo.purchases, CardPurchase.fromMap);
    await load('installments', repo.installments, Installment.fromMap);
    await load('recurringRules', repo.recurring, RecurringRule.fromMap);
    await load('subscriptions', repo.subscriptions, Subscription.fromMap);
    await load('budgets', repo.budgets, Budget.fromMap);
    await load('goals', repo.goals, Goal.fromMap);
    await load('contributions', repo.contributions, GoalContribution.fromMap);
    await load('assets', repo.assets, Asset.fromMap);
    await load('liabilities', repo.liabilities, Liability.fromMap);
    await load('notifications', repo.notifications, AppNotification.fromMap);

    // Reaplica as configurações, se houver.
    final settingsMap = data['settings'];
    if (settingsMap is Map) {
      await updateSettings(
          UserSettings.fromMap(Map<String, dynamic>.from(settingsMap)));
    }

    await repo.log(uid, 'restore', 'Backup', details: '$count registros');
    await refresh();
    return count;
  }

  /// Redefine os dados financeiros do usuário (mantém a conta e recria categorias).
  Future<void> resetFinancialData() async {
    final uid = _user!.id;
    for (final box in [
      repo.accounts,
      repo.categories,
      repo.transactions,
      repo.cards,
      repo.purchases,
      repo.installments,
      repo.recurring,
      repo.subscriptions,
      repo.budgets,
      repo.goals,
      repo.contributions,
      repo.assets,
      repo.liabilities,
      repo.notifications,
    ]) {
      await box.clearUser(uid);
    }
    await _seedDefaultCategories();
    await repo.accounts.put(Account(
      id: repo.newId(),
      userId: uid,
      name: 'Conta principal',
      type: AccountType.checking,
      balanceCents: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    await repo.log(uid, 'reset', 'Data');
    await refresh();
  }
}

/// Helper de comparação de datas.
class DateUtils {
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
