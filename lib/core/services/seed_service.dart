import '../db/repository.dart';
import '../models/models.dart';
import '../utils/category_icons.dart';

/// Seed de ambiente de DESENVOLVIMENTO (cap. 92).
/// Cria um usuário demo com contas, categorias, cartões, movimentações,
/// metas e orçamentos coerentes para demonstrar o IFinance funcionando de
/// verdade (dados persistentes, cálculos reais — não telas estáticas).
class SeedService {
  final Repository repo;
  SeedService(this.repo);

  Future<void> seedDemo(String userId) async {
    final now = DateTime.now();

    // ---- Categorias ----
    final catDefs = CategoryIcons.defaults;
    final categories = <Category>[];
    for (final d in catDefs) {
      categories.add(Category(
        id: repo.newId(),
        userId: userId,
        name: d.name,
        iconName: d.icon,
        colorValue: d.color,
        isIncome: d.isIncome,
        createdAt: now,
      ));
    }
    await repo.categories.putAll(categories);
    String catId(String name) =>
        categories.firstWhere((c) => c.name == name).id;

    // ---- Contas ----
    final accNubank = Account(
      id: repo.newId(),
      userId: userId,
      name: 'Nubank',
      institution: 'Nubank',
      type: AccountType.digital,
      balanceCents: 8_240_00,
      colorValue: 0xFF8B5CF6,
      createdAt: now,
      updatedAt: now,
    );
    final accItau = Account(
      id: repo.newId(),
      userId: userId,
      name: 'Itaú',
      institution: 'Itaú',
      type: AccountType.checking,
      balanceCents: 4_600_00,
      colorValue: 0xFFF59E0B,
      createdAt: now,
      updatedAt: now,
    );
    final accInvest = Account(
      id: repo.newId(),
      userId: userId,
      name: 'Investimentos',
      institution: 'XP',
      type: AccountType.investment,
      balanceCents: 23_500_00,
      colorValue: 0xFF10B981,
      createdAt: now,
      updatedAt: now,
    );
    await repo.accounts.putAll([accNubank, accItau, accInvest]);

    // ---- Cartões ----
    final cardPrincipal = CreditCard(
      id: repo.newId(),
      userId: userId,
      name: 'Cartão Principal',
      institution: 'Itaú',
      brand: CardBrand.visa,
      lastDigits: '4821',
      limitCents: 12_000_00,
      closingDay: 28,
      dueDay: 5,
      colorValue: 0xFF1E293B,
      createdAt: now,
      updatedAt: now,
    );
    final cardDigital = CreditCard(
      id: repo.newId(),
      userId: userId,
      name: 'Cartão Digital',
      institution: 'Nubank',
      brand: CardBrand.mastercard,
      lastDigits: '9012',
      limitCents: 8_000_00,
      closingDay: 20,
      dueDay: 28,
      colorValue: 0xFF7C3AED,
      createdAt: now,
      updatedAt: now,
    );
    await repo.cards.putAll([cardPrincipal, cardDigital]);

    // ---- Movimentações de contas ----
    final txns = <Transaction>[];

    // Receita: salário recebido
    txns.add(Transaction(
      id: repo.newId(),
      userId: userId,
      accountId: accItau.id,
      categoryId: catId('Salário'),
      type: TransactionType.income,
      description: 'Salário',
      amountCents: 12_550_00,
      competenceDate: DateTime(now.year, now.month, 5),
      dueDate: DateTime(now.year, now.month, 5),
      paidAt: DateTime(now.year, now.month, 5),
      incomeStatus: IncomeStatus.received,
      paymentMethod: PaymentMethod.transfer,
      createdAt: now,
      updatedAt: now,
    ));

    // Receita: freelancer prevista (futuro)
    txns.add(Transaction(
      id: repo.newId(),
      userId: userId,
      accountId: accNubank.id,
      categoryId: catId('Freelance'),
      type: TransactionType.income,
      description: 'Projeto freelance',
      amountCents: 2_000_00,
      competenceDate: DateTime(now.year, now.month + 1, 15),
      dueDate: DateTime(now.year, now.month + 1, 15),
      incomeStatus: IncomeStatus.expected,
      paymentMethod: PaymentMethod.transfer,
      createdAt: now,
      updatedAt: now,
    ));

    // Despesas fixas pagas
    void addExpense(String desc, int cents, String cat, int day,
        {PaymentMethod method = PaymentMethod.pix}) {
      final d = DateTime(now.year, now.month, day);
      txns.add(Transaction(
        id: repo.newId(),
        userId: userId,
        accountId: accItau.id,
        categoryId: catId(cat),
        type: TransactionType.expense,
        description: desc,
        amountCents: cents,
        competenceDate: d,
        dueDate: d,
        paidAt: d,
        expenseStatus: ExpenseStatus.paid,
        paymentMethod: method,
        createdAt: now,
        updatedAt: now,
      ));
    }

    addExpense('Aluguel', 3_000_00, 'Moradia', 5);
    addExpense('Supermercado', 184_90, 'Alimentação', 8);
    addExpense('Combustível', 150_00, 'Transporte', 9);
    addExpense('Farmácia', 89_90, 'Saúde', 10);
    addExpense('Internet', 119_90, 'Serviços', 7);
    addExpense('Escola dos filhos', 1_200_00, 'Filhos/Família', 6);
    addExpense('Academia', 129_90, 'Saúde', 4);
    addExpense('Restaurante', 240_00, 'Restaurantes', 12);
    addExpense('Uber', 78_50, 'Transporte', 11);

    // Despesas futuras previstas
    final d1 = DateTime(now.year, now.month, (now.day + 2).clamp(1, 28));
    txns.add(Transaction(
      id: repo.newId(),
      userId: userId,
      accountId: accItau.id,
      categoryId: catId('Moradia'),
      type: TransactionType.expense,
      description: 'Condomínio',
      amountCents: 850_00,
      competenceDate: d1,
      dueDate: d1,
      expenseStatus: ExpenseStatus.pending,
      paymentMethod: PaymentMethod.boleto,
      createdAt: now,
      updatedAt: now,
    ));
    final d2 = DateTime(now.year, now.month, (now.day + 4).clamp(1, 28));
    txns.add(Transaction(
      id: repo.newId(),
      userId: userId,
      accountId: accItau.id,
      categoryId: catId('Seguros'),
      type: TransactionType.expense,
      description: 'Seguro do carro',
      amountCents: 320_00,
      competenceDate: d2,
      dueDate: d2,
      expenseStatus: ExpenseStatus.pending,
      paymentMethod: PaymentMethod.boleto,
      createdAt: now,
      updatedAt: now,
    ));

    await repo.transactions.putAll(txns);

    // ---- Compra parcelada no cartão ----
    final purchase = CardPurchase(
      id: repo.newId(),
      userId: userId,
      creditCardId: cardPrincipal.id,
      categoryId: catId('Compras'),
      description: 'Notebook',
      totalCents: 4_800_00,
      installmentsCount: 12,
      firstReferenceMonth: DateTime(now.year, now.month - 1, 1),
      createdAt: now,
    );
    await repo.purchases.put(purchase);
    final amounts = _split(4_800_00, 12);
    final insts = <Installment>[];
    final instTx = <Transaction>[];
    for (var i = 0; i < 12; i++) {
      final ref = DateTime(now.year, now.month - 1 + i, 1);
      insts.add(Installment(
        id: repo.newId(),
        userId: userId,
        purchaseId: purchase.id,
        creditCardId: cardPrincipal.id,
        number: i + 1,
        totalCount: 12,
        amountCents: amounts[i],
        referenceMonth: ref,
        createdAt: now,
      ));
      instTx.add(Transaction(
        id: repo.newId(),
        userId: userId,
        creditCardId: cardPrincipal.id,
        categoryId: catId('Compras'),
        type: TransactionType.expense,
        description: 'Notebook (${i + 1}/12)',
        amountCents: amounts[i],
        competenceDate: ref,
        dueDate: ref,
        paymentMethod: PaymentMethod.credit,
        purchaseId: purchase.id,
        createdAt: now,
        updatedAt: now,
      ));
    }
    await repo.installments.putAll(insts);
    await repo.transactions.putAll(instTx);

    // Compra à vista no cartão digital
    await repo.transactions.put(Transaction(
      id: repo.newId(),
      userId: userId,
      creditCardId: cardDigital.id,
      categoryId: catId('Assinaturas'),
      type: TransactionType.expense,
      description: 'Netflix',
      amountCents: 55_90,
      competenceDate: DateTime(now.year, now.month, 3),
      dueDate: DateTime(now.year, now.month, 3),
      paymentMethod: PaymentMethod.credit,
      createdAt: now,
      updatedAt: now,
    ));
    await repo.transactions.put(Transaction(
      id: repo.newId(),
      userId: userId,
      creditCardId: cardDigital.id,
      categoryId: catId('Assinaturas'),
      type: TransactionType.expense,
      description: 'Spotify',
      amountCents: 21_90,
      competenceDate: DateTime(now.year, now.month, 5),
      dueDate: DateTime(now.year, now.month, 5),
      paymentMethod: PaymentMethod.credit,
      createdAt: now,
      updatedAt: now,
    ));

    // ---- Recorrências ----
    await repo.recurring.putAll([
      RecurringRule(
        id: repo.newId(),
        userId: userId,
        description: 'Aluguel',
        type: TransactionType.expense,
        amountCents: 3_000_00,
        accountId: accItau.id,
        categoryId: catId('Moradia'),
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(now.year, now.month, 5),
        preferredDayOfMonth: 5,
        createdAt: now,
        updatedAt: now,
      ),
      RecurringRule(
        id: repo.newId(),
        userId: userId,
        description: 'Salário',
        type: TransactionType.income,
        amountCents: 12_550_00,
        accountId: accItau.id,
        categoryId: catId('Salário'),
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(now.year, now.month, 5),
        preferredDayOfMonth: 5,
        createdAt: now,
        updatedAt: now,
      ),
      RecurringRule(
        id: repo.newId(),
        userId: userId,
        description: 'Internet',
        type: TransactionType.expense,
        amountCents: 119_90,
        accountId: accItau.id,
        categoryId: catId('Serviços'),
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(now.year, now.month, 7),
        preferredDayOfMonth: 7,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    // ---- Assinaturas ----
    await repo.subscriptions.putAll([
      Subscription(
        id: repo.newId(),
        userId: userId,
        name: 'Netflix',
        amountCents: 55_90,
        frequency: RecurrenceFrequency.monthly,
        creditCardId: cardDigital.id,
        categoryId: catId('Assinaturas'),
        nextChargeDate: DateTime(now.year, now.month + 1, 3),
        createdAt: now,
      ),
      Subscription(
        id: repo.newId(),
        userId: userId,
        name: 'Spotify',
        amountCents: 21_90,
        frequency: RecurrenceFrequency.monthly,
        creditCardId: cardDigital.id,
        categoryId: catId('Assinaturas'),
        nextChargeDate: DateTime(now.year, now.month + 1, 5),
        createdAt: now,
      ),
      Subscription(
        id: repo.newId(),
        userId: userId,
        name: 'iCloud',
        amountCents: 12_90,
        frequency: RecurrenceFrequency.monthly,
        creditCardId: cardDigital.id,
        categoryId: catId('Assinaturas'),
        nextChargeDate: DateTime(now.year, now.month + 1, 12),
        createdAt: now,
      ),
    ]);

    // ---- Orçamentos ----
    await repo.budgets.putAll([
      Budget(
        id: repo.newId(),
        userId: userId,
        categoryId: catId('Alimentação'),
        limitCents: 1_500_00,
        createdAt: now,
      ),
      Budget(
        id: repo.newId(),
        userId: userId,
        categoryId: catId('Transporte'),
        limitCents: 600_00,
        createdAt: now,
      ),
      Budget(
        id: repo.newId(),
        userId: userId,
        categoryId: catId('Lazer'),
        limitCents: 500_00,
        createdAt: now,
      ),
      Budget(
        id: repo.newId(),
        userId: userId,
        categoryId: catId('Restaurantes'),
        limitCents: 800_00,
        createdAt: now,
      ),
    ]);

    // ---- Metas ----
    await repo.goals.putAll([
      Goal(
        id: repo.newId(),
        userId: userId,
        name: 'Viagem',
        targetCents: 10_000_00,
        accumulatedCents: 6_200_00,
        deadline: DateTime(now.year, now.month + 5, 1),
        iconName: 'travel',
        colorValue: 0xFF06B6D4,
        createdAt: now,
        updatedAt: now,
      ),
      Goal(
        id: repo.newId(),
        userId: userId,
        name: 'Reserva Financeira',
        targetCents: 42_000_00,
        accumulatedCents: 23_500_00,
        type: GoalType.emergencyReserve,
        emergencyMonths: 6,
        iconName: 'insurance',
        colorValue: 0xFF10B981,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    // ---- Patrimônio ----
    await repo.assets.putAll([
      Asset(
        id: repo.newId(),
        userId: userId,
        name: 'Carro',
        type: AssetType.vehicle,
        valueCents: 65_000_00,
        createdAt: now,
      ),
      Asset(
        id: repo.newId(),
        userId: userId,
        name: 'Apartamento',
        type: AssetType.realEstate,
        valueCents: 320_000_00,
        createdAt: now,
      ),
    ]);

    await repo.liabilities.putAll([
      Liability(
        id: repo.newId(),
        userId: userId,
        description: 'Financiamento do carro',
        creditor: 'Banco X',
        type: LiabilityType.financing,
        originalCents: 80_000_00,
        outstandingCents: 42_000_00,
        installmentsCount: 60,
        currentInstallment: 38,
        monthlyPaymentCents: 1_320_00,
        dueDate: DateTime(now.year, now.month, 15),
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    // ---- Configurações ----
    await repo.settings.put(UserSettings(
      userId: userId,
      safetyMarginPercent: 10,
      protectedReserveCents: 0,
      excludeInvestmentsFromDailyBalance: true,
      essentialMonthlyCostCents: 7_000_00,
      themeMode: AppThemeMode.system,
    ));

    await repo.log(userId, 'seed', 'Database', details: 'demo');
  }

  static List<int> _split(int total, int n) {
    final base = total ~/ n;
    final rem = total - base * n;
    return List<int>.generate(n, (i) => base + (i < rem ? 1 : 0));
  }
}
