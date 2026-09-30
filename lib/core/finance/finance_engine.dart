import 'dart:math';

import '../models/models.dart';
import '../utils/date_helpers.dart';
import '../utils/money.dart';
import 'finance_models.dart';
import 'recurrence_materializer.dart';

/// Informação de próxima receita (data + valor).
typedef IncomeInfo = ({DateTime date, int amount});

/// IFinance FinanceEngine — motor financeiro central (cap. 62).
///
/// Toda a inteligência financeira vive AQUI, nunca na UI (cap. 56/89).
/// Valores em CENTAVOS (int). Regras contábeis consistentes:
/// - Transferências não são receita/despesa e têm impacto zero no resultado
///   consolidado (cap. 17);
/// - Compra no cartão é despesa econômica; pagamento de fatura é movimentação
///   de caixa — nunca contadas duas vezes (cap. 20).
class FinanceEngine {
  FinanceEngine({
    required this.userId,
    required List<Account> accounts,
    required List<Transaction> transactions,
    required this.categories,
    required List<CreditCard> cards,
    required this.installments,
    required this.purchases,
    required List<RecurringRule> recurringRules,
    required List<Subscription> subscriptions,
    required this.settings,
  })  : accounts = accounts.where((a) => !a.archived).toList(),
        transactions = transactions
            .where((t) => !t.deleted && t.userId == userId)
            .toList(),
        cards = cards.where((c) => !c.archived).toList(),
        recurringRules = recurringRules.where((r) => r.active).toList(),
        subscriptions = subscriptions.where((s) => s.active).toList();

  final String userId;
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Category> categories;
  final List<CreditCard> cards;
  final List<Installment> installments;
  final List<CardPurchase> purchases;
  final List<RecurringRule> recurringRules;
  final List<Subscription> subscriptions;
  final UserSettings settings;

  // ---------------------------------------------------------------------------
  // 63. SALDO ATUAL
  // ---------------------------------------------------------------------------

  /// Soma dos saldos reconciliados das contas incluídas no patrimônio
  /// financeiro disponível. Investimentos podem ser excluídos conforme config.
  int getCurrentBalance({bool excludeInvestments = true}) {
    return accounts.where((a) {
      if (!a.includeInNetWorth) return false;
      if (excludeInvestments &&
          settings.excludeInvestmentsFromDailyBalance &&
          a.type == AccountType.investment) {
        return false;
      }
      return true;
    }).fold(0, (sum, a) => sum + a.balanceCents);
  }

  int getInvestmentsBalance() => accounts
      .where((a) => a.type == AccountType.investment)
      .fold(0, (sum, a) => sum + a.balanceCents);

  int balanceOfAccount(String accountId) {
    final acc = accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => Account(
          id: accountId,
          userId: userId,
          name: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
    );
    return acc.balanceCents;
  }

  // ---------------------------------------------------------------------------
  // Dinheiro disponível em uma data (considerando movimento de caixa real)
  // ---------------------------------------------------------------------------

  /// Saldo real das contas em [date], aplicando todas as movimentações de caixa
  /// (transferências, receitas recebidas, despesas pagas, pagamentos de fatura)
  /// com data <= [date]. NÃO inclui compromissos futuros.
  int cashBalanceAt(DateTime date, {bool excludeInvestments = true}) {
    var balance = getCurrentBalance(excludeInvestments: excludeInvestments);
    for (final t in transactions) {
      if (t.isIncome &&
          !t.isTransfer &&
          t.paidAt != null &&
          DateHelpers.dateOnly(t.paidAt!).isAfter(DateHelpers.dateOnly(date))) {
        balance -= t.amountCents;
      }
    }
    return balance;
  }

  // ---------------------------------------------------------------------------
  // Eventos de caixa (movimentações de caixa realizadas + previstas)
  // ---------------------------------------------------------------------------

  /// Eventos de caixa realizados e previstos dentro de uma janela.
  /// Compras no cartão NÃO entram aqui (não afetam o caixa até o pagamento —
  /// cap. 20); entram as faturas em vencimento.
  List<CashEvent> cashEvents({required DateTime from, required DateTime to}) {
    final fromD = DateHelpers.dateOnly(from);
    final toD = DateHelpers.dateOnly(to);
    final events = <CashEvent>[];

    // 1) Movimentações reais.
    for (final t in transactions) {
      if (t.isTransfer) continue;
      if (t.creditCardId != null && !t.isInvoicePayment) continue; // compra cartão
      final effectiveDate = t.paidAt ?? t.dueDate;
      final d = DateHelpers.dateOnly(effectiveDate);
      if (d.isBefore(fromD) || d.isAfter(toD)) continue;
      final amount = t.isIncome ? t.amountCents : -t.amountCents;
      events.add(CashEvent(
        date: d,
        label: t.description.isEmpty
            ? (t.isIncome ? 'Receita' : 'Despesa')
            : t.description,
        amountCents: amount,
        kind: t.isIncome
            ? FinancialEventKind.income
            : FinancialEventKind.expense,
        sourceId: t.id,
        confirmed: t.paidAt != null,
      ));
    }

    final now = DateHelpers.dateOnly(DateTime.now());

    // 2) Faturas de cartão em vencimento (não pagas).
    for (final inv in _invoicesWithTotals()) {
      if (inv.paidAt != null) continue;
      final d = DateHelpers.dateOnly(inv.dueDate);
      if (d.isBefore(fromD) || d.isAfter(toD)) continue;
      final card =
          cards.where((c) => c.id == inv.creditCardId).fold<String>('', (_, c) => c.name);
      events.add(CashEvent(
        date: d,
        label: 'Fatura ${card.isNotEmpty ? card : 'cartão'}',
        amountCents: -inv.totalCents,
        kind: FinancialEventKind.cardInvoice,
        confirmed: false,
      ));
    }

    // 3) Recorrências (receitas/despesas) previstas, exceto as que tiverem
    //    ocorrência real correspondente no período.
    final realizedKeys = {
      for (final t in transactions)
        '${t.recurringRuleId ?? t.description}|${t.dueDate.toIso8601String().substring(0, 10)}'
    };
    for (final rule in recurringRules) {
      for (final occ in RecurrenceMaterializer.occurrencesInWindow(
          rule, fromD, toD)) {
        final key = '${rule.id}|${occ.toIso8601String().substring(0, 10)}';
        if (realizedKeys.contains(key)) continue;
        // Se já existe transação real da mesma regra na mesma data, ignora.
        if (transactions.any((t) =>
            t.recurringRuleId == rule.id &&
            DateHelpers.isSameDay(t.dueDate, occ))) {
          continue;
        }
        final amount =
            rule.type == TransactionType.income ? rule.amountCents : -rule.amountCents;
        events.add(CashEvent(
          date: occ,
          label: rule.description,
          amountCents: amount,
          kind: rule.type == TransactionType.income
              ? FinancialEventKind.income
              : FinancialEventKind.expense,
          sourceId: rule.id,
          confirmed: occ.isBefore(now),
        ));
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  // ---------------------------------------------------------------------------
  // 64. COMPROMETIDO (depende do horizonte)
  // ---------------------------------------------------------------------------

  /// Obrigações (saídas esperadas) até [until], considerando faturas, despesas
  /// previstas/pendentes, parcelas do cartão e recorrências futuras.
  /// Transferências não comprometem o resultado consolidado (cap. 17).
  int getCommittedAmount({required DateTime until}) {
    final today = DateHelpers.dateOnly(DateTime.now());
    final untilD = DateHelpers.dateOnly(until);
    var committed = 0;

    // Despesas em contas (não cartão) ainda não pagas, com vencimento até `until`.
    for (final t in transactions) {
      if (!t.isExpense || t.isTransfer || t.isInvoicePayment) continue;
      if (t.creditCardId != null) continue; // despesa econômica de cartão
      if (t.paidAt != null) continue;
      if (t.expenseStatus == ExpenseStatus.cancelled) continue;
      final d = DateHelpers.dateOnly(t.dueDate);
      if (!d.isAfter(untilD)) committed += t.amountCents;
    }

    // Faturas de cartão não pagas com vencimento até `until`.
    for (final inv in _invoicesWithTotals()) {
      if (inv.paidAt != null) continue;
      final d = DateHelpers.dateOnly(inv.dueDate);
      if (!d.isAfter(untilD)) committed += inv.totalCents;
    }

    // Recorrências futuras (a partir de amanhã) dentro do horizonte.
    final from = DateHelpers.addDays(today, 1);
    if (!from.isAfter(untilD)) {
      for (final rule in recurringRules) {
        if (rule.type != TransactionType.expense) continue;
        for (final occ in RecurrenceMaterializer.occurrencesInWindow(
            rule, from, untilD)) {
          if (transactions.any((t) =>
              t.recurringRuleId == rule.id &&
              DateHelpers.isSameDay(t.dueDate, occ))) {
            continue;
          }
          committed += rule.amountCents;
        }
      }
    }
    return committed;
  }

  // ---------------------------------------------------------------------------
  // 65. SALDO LIVRE SEGURO
  // ---------------------------------------------------------------------------

  /// Saldo disponível − compromissos do horizonte − reservas protegidas −
  /// margem de segurança. Receitas futuras NÃO são tratadas como dinheiro
  /// disponível hoje (cap. 65).
  int getSafeAvailableBalance({required DateTime until}) {
    final available = getCurrentBalance();
    final committed = getCommittedAmount(until: until);
    final reserves = settings.protectedReserveCents;
    final margin =
        Money.applyPercent(available, settings.safetyMarginPercent);
    final safe = available - committed - reserves - margin;
    return safe;
  }

  /// Explicação detalhada do saldo livre (cap. 39).
  CalcExplanation explainSafeAvailable({required DateTime until}) {
    final available = getCurrentBalance();
    final committed = getCommittedAmount(until: until);
    final reserves = settings.protectedReserveCents;
    final margin =
        Money.applyPercent(available, settings.safetyMarginPercent);
    final result = available - committed - reserves - margin;
    return CalcExplanation(
      title: 'Saldo livre seguro',
      components: [
        CalcComponent('Saldo em contas', available),
        CalcComponent('Compromissos considerados', committed,
            isSubtraction: true),
        if (reserves > 0)
          CalcComponent('Reservas protegidas', reserves, isSubtraction: true),
        if (margin > 0)
          CalcComponent(
              'Margem de segurança (${settings.safetyMarginPercent.toStringAsFixed(0)}%)',
              margin,
              isSubtraction: true),
      ],
      resultCents: result,
    );
  }

  // ---------------------------------------------------------------------------
  // 66/67. SALDO PROJETADO E MENOR SALDO
  // ---------------------------------------------------------------------------

  /// 66. Saldo projetado em [targetDate]:
  /// saldo atual + entradas previstas − saídas previstas até T.
  /// Em modo "pessimista" (default) só considera receitas confirmadas como
  /// evitáveis de contar? Não: projeção inclui previstas (cap. 66).
  int getProjectedBalance(DateTime targetDate) {
    final today = DateHelpers.dateOnly(DateTime.now());
    final target = DateHelpers.dateOnly(targetDate);
    var balance = getCurrentBalance();
    final events = cashEvents(from: today, to: target);
    for (final e in events) {
      if (e.confirmed) continue; // já refletido no saldo atual
      balance += e.amountCents;
    }
    return balance;
  }

  /// 67. Percorre eventos cronologicamente, recalculando o saldo após cada um,
  /// e guarda o MENOR valor encontrado.
  ({int balance, DateTime? date}) getLowestProjectedBalance({
    required DateTime until,
  }) {
    final today = DateHelpers.dateOnly(DateTime.now());
    final untilD = DateHelpers.dateOnly(until);
    var balance = getCurrentBalance();
    var lowest = balance;
    DateTime? lowestDate;

    final events = cashEvents(from: today, to: untilD);
    for (final e in events) {
      if (e.confirmed) continue;
      balance += e.amountCents;
      if (balance < lowest) {
        lowest = balance;
        lowestDate = e.date;
      }
    }
    return (balance: lowest, date: lowestDate);
  }

  /// Série de projeção dia a dia (para o gráfico — cap. 25).
  List<ProjectionPoint> buildProjectionSeries({required DateTime until}) {
    final today = DateHelpers.dateOnly(DateTime.now());
    final untilD = DateHelpers.dateOnly(until);
    final events = cashEvents(from: today, to: untilD)
        .where((e) => !e.confirmed)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final points = <ProjectionPoint>[];
    var balance = getCurrentBalance();
    points.add(ProjectionPoint(today, balance, true));

    var idx = 0;
    var cursor = today;
    final totalDays = DateHelpers.daysBetween(today, untilD);
    final step = (totalDays / 60).ceil().clamp(1, 31);
    while (!cursor.isAfter(untilD)) {
      while (idx < events.length &&
          !DateHelpers.dateOnly(events[idx].date).isAfter(cursor)) {
        balance += events[idx].amountCents;
        idx++;
      }
      points.add(ProjectionPoint(cursor, balance, false));
      cursor = DateHelpers.addDays(cursor, step);
    }
    // Garante o ponto final exato.
    while (idx < events.length) {
      balance += events[idx].amountCents;
      idx++;
    }
    if (points.isEmpty || !DateHelpers.isSameDay(points.last.date, untilD)) {
      points.add(ProjectionPoint(untilD, balance, false));
    }
    return points;
  }

  // ---------------------------------------------------------------------------
  // Próxima receita / próximos eventos
  // ---------------------------------------------------------------------------

  IncomeInfo? getNextIncome({DateTime? after}) {
    final now = after ?? DateHelpers.dateOnly(DateTime.now());
    final events = cashEvents(
      from: now,
      to: DateHelpers.addDays(now, 120),
    ).where((e) => e.isInflow).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (events.isEmpty) return null;
    return (date: events.first.date, amount: events.first.amountCents);
  }

  DateTime horizonEndDate(Horizon horizon, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    switch (horizon) {
      case Horizon.today:
        return DateHelpers.dateOnly(now);
      case Horizon.nextIncome:
        final next = getNextIncome();
        if (next == null) return DateHelpers.endOfMonth(now);
        return next.date;
      case Horizon.month:
        return DateHelpers.endOfMonth(now);
    }
  }

  // ---------------------------------------------------------------------------
  // 9/10. RESUMO DO MÊS e FLUXO
  // ---------------------------------------------------------------------------

  /// 9. Resumo do mês: receitas, despesas econômicas e resultado.
  MonthlySummary getMonthlySummary([DateTime? month]) {
    final ref = month ?? DateTime.now();
    final start = DateHelpers.startOfMonth(ref);
    final end = DateHelpers.endOfMonth(ref);

    var income = 0;
    var expense = 0;

    for (final t in transactions) {
      if (t.isTransfer) continue;
      if (!DateHelpers.dateOnly(t.competenceDate).isAfter(end) &&
          !DateHelpers.dateOnly(t.competenceDate).isBefore(start)) {
        if (t.isIncome) {
          income += t.amountCents;
        } else if (t.isEconomicExpense) {
          expense += t.amountCents;
        }
      }
    }

    return MonthlySummary(
      month: start,
      incomeCents: income,
      expenseCents: expense,
      resultCents: income - expense,
      committedIncomeCents: expense,
      committedPercent: income == 0 ? 0 : (expense / income) * 100,
    );
  }

  /// 10. Fluxo mensal (Receitas x Despesas) para gráfico.
  List<FlowPoint> getFlow({int months = 6, DateTime? end}) {
    final endMonth = end ?? DateTime.now();
    final result = <FlowPoint>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateHelpers.addMonths(endMonth, -i);
      final s = getMonthlySummary(m);
      result.add(FlowPoint(
        month: DateHelpers.startOfMonth(m),
        incomeCents: s.incomeCents,
        expenseCents: s.expenseCents,
      ));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // 26. ORÇAMENTOS
  // ---------------------------------------------------------------------------

  List<BudgetUsage> getBudgetUsage(
      List<Budget> budgets, [DateTime? month]) {
    final ref = month ?? DateTime.now();
    final start = DateHelpers.startOfMonth(ref);
    final end = DateHelpers.endOfMonth(ref);
    return budgets.where((b) => b.active).map((b) {
      final cat = categories.where((c) => c.id == b.categoryId);
      final name = cat.isNotEmpty ? cat.first.name : 'Categoria';
      var consumed = 0;
      for (final t in transactions) {
        if (t.categoryId != b.categoryId) continue;
        if (!t.isExpense || t.isTransfer) continue;
        if (DateHelpers.dateOnly(t.competenceDate).isBefore(start) ||
            DateHelpers.dateOnly(t.competenceDate).isAfter(end)) {
          continue;
        }
        consumed += t.amountCents;
      }
      return BudgetUsage(
        budgetId: b.id,
        categoryId: b.categoryId,
        categoryName: name,
        limitCents: b.limitCents,
        consumedCents: consumed,
      );
    }).toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));
  }

  int getTotalExpensesThisMonth() {
    final s = getMonthlySummary();
    return s.expenseCents;
  }

  // ---------------------------------------------------------------------------
  // 18/19/20/21. CARTÕES, FATURAS E PARCELAMENTOS
  // ---------------------------------------------------------------------------

  /// Total de uma fatura: compras à vista + parcelas do mês de referência.
  int invoiceTotal(String cardId, DateTime referenceMonth) {
    var total = 0;
    final refStart = DateHelpers.startOfMonth(referenceMonth);
    for (final t in transactions) {
      if (t.creditCardId != cardId || !t.isExpense) continue;
      if (t.isInvoicePayment) continue;
      if (t.purchaseId != null) continue; // parceladas via installments
      if (DateHelpers.isSameMonth(t.competenceDate, refStart)) {
        total += t.amountCents;
      }
    }
    for (final inst in installments) {
      if (inst.creditCardId != cardId) continue;
      if (DateHelpers.isSameMonth(inst.referenceMonth, refStart)) {
        total += inst.amountCents;
      }
    }
    return total;
  }

  /// Fatura atual aberta (mês de referência corrente).
  int getCurrentInvoiceTotal(String cardId) =>
      invoiceTotal(cardId, DateTime.now());

  /// Próxima fatura (mês seguinte).
  int getNextInvoiceTotal(String cardId) =>
      invoiceTotal(cardId, DateHelpers.addMonths(DateTime.now(), 1));

  /// Crédito comprometido no cartão (todas as compras/parcelas não pagas).
  int getCardUsed(String cardId) {
    var used = 0;
    for (final t in transactions) {
      if (t.creditCardId != cardId || !t.isExpense) continue;
      if (t.isInvoicePayment) continue;
      if (t.purchaseId != null) continue;
      used += t.amountCents;
    }
    // Apenas parcelas futuras/não pagas contam para o limite utilizado.
    for (final inst in installments) {
      if (inst.creditCardId != cardId) continue;
      used += inst.amountCents;
    }
    // Subtrai valores já pagos de faturas de meses anteriores.
    for (final inv in _paidInvoiceAmounts(cardId)) {
      used -= inv;
    }
    return used < 0 ? 0 : used;
  }

  List<int> _paidInvoiceAmounts(String cardId) {
    final paid = <int>[];
    for (final t in transactions) {
      if (t.creditCardId == cardId && t.isInvoicePayment && t.paidAt != null) {
        paid.add(t.amountCents);
      }
    }
    return paid;
  }

  int getCardAvailable(String cardId) {
    final card = cards.where((c) => c.id == cardId);
    if (card.isEmpty) return 0;
    final avail = card.first.limitCents - getCardUsed(cardId);
    return avail < 0 ? 0 : avail;
  }

  /// Compras que compõem a fatura (para detalhamento — cap. 19).
  List<Transaction> invoiceTransactions(String cardId, DateTime referenceMonth) {
    final refStart = DateHelpers.startOfMonth(referenceMonth);
    return transactions.where((t) {
      if (t.creditCardId != cardId || !t.isExpense) return false;
      if (t.isInvoicePayment) return false;
      if (t.purchaseId != null) return false;
      return DateHelpers.isSameMonth(t.competenceDate, refStart);
    }).toList()
      ..sort((a, b) => b.competenceDate.compareTo(a.competenceDate));
  }

  List<Installment> invoiceInstallments(String cardId, DateTime referenceMonth) {
    final refStart = DateHelpers.startOfMonth(referenceMonth);
    return installments
        .where((i) => i.creditCardId == cardId &&
            DateHelpers.isSameMonth(i.referenceMonth, refStart))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 62. getCashFlow / getNetWorth
  // ---------------------------------------------------------------------------

  NetWorth getNetWorth({List<Asset> others = const [], List<Liability>? liabilities = const []}) {
    var assetsTotal = accounts
        .where((a) => a.includeInNetWorth)
        .fold<int>(0, (s, a) => s + a.balanceCents);
    for (final a in others) {
      if (!a.archived) assetsTotal += a.valueCents;
    }
    var liabilitiesTotal = 0;
    for (final l in (liabilities ?? <Liability>[])) {
      if (!l.archived) liabilitiesTotal += l.outstandingCents;
    }
    return NetWorth(
      assetsCents: assetsTotal,
      liabilitiesCents: liabilitiesTotal,
      netCents: assetsTotal - liabilitiesTotal,
    );
  }

  // ---------------------------------------------------------------------------
  // 11. RADAR FINANCEIRO (próximos 7 dias + insights)
  // ---------------------------------------------------------------------------

  RadarData getRadar({int days = 7}) {
    final today = DateHelpers.dateOnly(DateTime.now());
    final end = DateHelpers.addDays(today, days);
    final events = cashEvents(from: today, to: end)
        .where((e) => !e.confirmed)
        .toList();

    var payments = 0;
    var paymentsCount = 0;
    var receipts = 0;
    for (final e in events) {
      if (e.isInflow) {
        receipts += e.amountCents;
      } else {
        payments += -e.amountCents;
        paymentsCount++;
      }
    }

    final nextIncome = getNextIncome();
    final insights = <Insight>[];

    final lowest = getLowestProjectedBalance(until: end);
    final balanceToday = getCurrentBalance();

    if (balanceToday >= payments && lowest.balance >= 0) {
      insights.add(const Insight(
        severity: InsightSeverity.positive,
        title: 'Fluxo sob controle',
        message: 'Tudo sob controle nos próximos 7 dias.',
      ));
    }
    if (lowest.date != null && lowest.balance >= 0) {
      insights.add(Insight(
        severity: InsightSeverity.info,
        title: 'Ponto de menor saldo',
        message:
            '${DateHelpers.weekdayNames[lowest.date!.weekday - 1]} será o ponto de menor saldo do período (${_brl(lowest.balance)}).',
      ));
    }
    if (lowest.balance < 0) {
      insights.add(Insight(
        severity: InsightSeverity.critical,
        title: 'Saldo pode ficar negativo',
        message:
            'Atenção: seu saldo projetado pode ficar negativo (${_brl(lowest.balance)})${lowest.date != null ? ' em ${DateHelpers.dayMonth.format(lowest.date!)}' : ''}.',
      ));
    }

    // Fatura vencendo em breve.
    for (final inv in _invoicesWithTotals()) {
      if (inv.paidAt != null) continue;
      final d = DateHelpers.daysUntil(inv.dueDate);
      if (d >= 0 && d <= 3) {
        insights.add(Insight(
          severity: d == 0 ? InsightSeverity.critical : InsightSeverity.warning,
          title: 'Fatura do cartão',
          message: d == 0
              ? 'Sua fatura vence hoje.'
              : 'Sua fatura vence em $d ${d == 1 ? 'dia' : 'dias'}.',
        ));
      }
    }

    // Assinaturas previstas na semana.
    final subsThisWeek = subscriptions.where((s) {
      final d = DateHelpers.dateOnly(s.nextChargeDate);
      return !d.isBefore(today) && !d.isAfter(end);
    }).length;
    if (subsThisWeek > 0) {
      insights.add(Insight(
        severity: InsightSeverity.info,
        title: 'Assinaturas',
        message:
            'Você possui $subsThisWeek assinatura${subsThisWeek > 1 ? 's' : ''} prevista${subsThisWeek > 1 ? 's' : ''} nesta semana.',
      ));
    }

    return RadarData(
      days: days,
      paymentsCount: paymentsCount,
      paymentsCents: payments,
      receiptsCents: receipts,
      nextIncomeDate: nextIncome?.date,
      nextIncomeCents: nextIncome?.amount ?? 0,
      insights: insights,
    );
  }

  // ---------------------------------------------------------------------------
  // 31. ASSINATURAS
  // ---------------------------------------------------------------------------

  int getSubscriptionsMonthlyCost() =>
      subscriptions.fold(0, (s, sub) => s + sub.monthlyCents);

  int getSubscriptionsAnnualCost() =>
      subscriptions.fold(0, (s, sub) => s + sub.annualCents);

  // ---------------------------------------------------------------------------
  // 36/38. NEY ASSESSOR — consultas estruturadas (a IA explica, não calcula).
  // ---------------------------------------------------------------------------

  /// "Quanto posso gastar?" (cap. 38): margem livre considerando compromissos
  /// antes da próxima receita e margem configurada.
  Map<String, dynamic> assistantSafeToSpend() {
    final next = getNextIncome();
    final until = next?.date ?? DateHelpers.endOfMonth(DateTime.now());
    final available = getCurrentBalance();
    final committed = getCommittedAmount(until: until);
    final margin = Money.applyPercent(available, settings.safetyMarginPercent);
    final reserves = settings.protectedReserveCents;
    final free = available - committed - reserves - margin;
    return {
      'available': available,
      'committed': committed,
      'margin': margin,
      'reserves': reserves,
      'free': free,
      'until': until,
      'nextIncome': next?.amount ?? 0,
      'nextIncomeDate': next?.date,
    };
  }

  Map<String, dynamic> assistantMonthOutlook() {
    final s = getMonthlySummary();
    final until = DateHelpers.endOfMonth(DateTime.now());
    return {
      'income': s.incomeCents,
      'expense': s.expenseCents,
      'result': s.resultCents,
      'projectedEnd': getProjectedBalance(until),
      'committed': s.expenseCents,
    };
  }

  /// "Onde estou gastando mais?"
  List<({String name, int amount})> assistantTopCategories({int limit = 5}) {
    final start = DateHelpers.startOfMonth(DateTime.now());
    final end = DateHelpers.endOfMonth(DateTime.now());
    final map = <String, int>{};
    for (final t in transactions) {
      if (!t.isEconomicExpense) continue;
      if (DateHelpers.dateOnly(t.competenceDate).isBefore(start) ||
          DateHelpers.dateOnly(t.competenceDate).isAfter(end)) {
        continue;
      }
      final catId = t.categoryId ?? 'none';
      map[catId] = (map[catId] ?? 0) + t.amountCents;
    }
    final list = map.entries.map((e) {
      final cat = categories.where((c) => c.id == e.key);
      final name = cat.isNotEmpty ? cat.first.name : 'Sem categoria';
      return (name: name, amount: e.value);
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list.take(limit).toList();
  }

  Map<String, dynamic> assistantCommitted() {
    final until = DateHelpers.endOfMonth(DateTime.now());
    return {
      'committedMonth': getCommittedAmount(until: until),
      'committedToday': getCommittedAmount(until: DateHelpers.dateOnly(DateTime.now())),
    };
  }

  Map<String, dynamic> assistantCardStatus() {
    final result = <Map<String, dynamic>>[];
    for (final c in cards) {
      result.add({
        'name': c.name,
        'currentInvoice': getCurrentInvoiceTotal(c.id),
        'nextInvoice': getNextInvoiceTotal(c.id),
        'used': getCardUsed(c.id),
        'available': getCardAvailable(c.id),
        'limit': c.limitCents,
      });
    }
    return {'cards': result};
  }

  // ---------------------------------------------------------------------------
  // 87. HOME — retrato consolidado (cap. 74: resposta agregada)
  // ---------------------------------------------------------------------------

  DashboardData buildDashboard(Horizon horizon) {
    final until = horizonEndDate(horizon);
    final available = getCurrentBalance();
    final committed = getCommittedAmount(until: until);
    final safe = getSafeAvailableBalance(until: until);
    final lowest = getLowestProjectedBalance(until: until);
    final monthEnd = DateHelpers.endOfMonth(DateTime.now());

    return DashboardData(
      horizon: horizon,
      currentBalanceCents: available,
      committedCents: committed,
      safeAvailableCents: safe,
      projectedMonthEndCents: getProjectedBalance(monthEnd),
      monthSummary: getMonthlySummary(),
      radar: getRadar(),
      upcomingEvents: upcomingEvents(limit: 5),
      lowestProjectedBalanceCents: lowest.balance,
      lowestProjectedBalanceDate: lowest.date,
    );
  }

  List<CashEvent> upcomingEvents({int limit = 6}) {
    final today = DateHelpers.dateOnly(DateTime.now());
    return cashEvents(from: today, to: DateHelpers.addDays(today, 60))
        .where((e) => !e.confirmed)
        .take(limit)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Faturas com totais calculados a partir das compras/parcelas.
  List<Invoice> _invoicesWithTotals() {
    final now = DateTime.now();
    final result = <Invoice>[];
    // Cobre desde 6 meses atrás até 12 meses à frente.
    for (final card in cards) {
      for (var i = -6; i <= 12; i++) {
        final ref = DateHelpers.addMonths(now, i);
        final total = invoiceTotal(card.id, ref);
        if (total <= 0 && i > 0) continue;
        if (total <= 0 && i < 0) continue;
        result.add(_buildInvoice(card, ref, total));
      }
    }
    return result;
  }

  Invoice _buildInvoice(CreditCard card, DateTime ref, int total) {
    final refStart = DateHelpers.startOfMonth(ref);
    final closing = _safeDate(ref.year, ref.month, card.closingDay);
    final due = _safeDate(ref.year, ref.month, card.dueDay);
    final paidTx = transactions.where((t) =>
        t.creditCardId == card.id &&
        t.isInvoicePayment &&
        t.paidAt != null &&
        t.invoiceReferenceMonth != null &&
        DateHelpers.isSameMonth(t.invoiceReferenceMonth!, refStart));
    final paid = paidTx.isNotEmpty;
    final now = DateHelpers.dateOnly(DateTime.now());
    final status = paid
        ? InvoiceStatus.paid
        : (due.isBefore(now) ? InvoiceStatus.overdue : InvoiceStatus.open);
    return Invoice(
      id: '${card.id}_${ref.year}_${ref.month}',
      userId: userId,
      creditCardId: card.id,
      referenceMonth: refStart,
      closingDate: closing,
      dueDate: due,
      totalCents: total,
      paidAt: paid ? paidTx.first.paidAt : null,
      status: status,
    );
  }

  DateTime _safeDate(int year, int month, int day) {
    final maxDay = DateHelpers.daysInMonth(year, month);
    return DateTime(year, month, day.clamp(1, maxDay));
  }

  static String _brl(int cents) => Money.format(cents);

  // ---------------------------------------------------------------------------
  // 27. METAS — cálculo de contribuição mensal necessária
  // ---------------------------------------------------------------------------

  int monthlyNeededForGoal(Goal goal, {DateTime? from}) {
    final remaining = goal.remainingCents;
    if (goal.deadline == null) return remaining;
    final now = from ?? DateTime.now();
    final months = DateHelpers.monthsBetween(now, goal.deadline!);
    if (months <= 0) return remaining;
    return (remaining / months).ceil();
  }

  // ---------------------------------------------------------------------------
  // 12. Timeline de próximos eventos com saldo após cada evento
  // ---------------------------------------------------------------------------

  List<({CashEvent event, int balanceAfter})> timeline({int days = 60}) {
    final today = DateHelpers.dateOnly(DateTime.now());
    final events = cashEvents(from: today, to: DateHelpers.addDays(today, days))
        .where((e) => !e.confirmed)
        .toList();
    var balance = getCurrentBalance();
    final result = <({CashEvent event, int balanceAfter})>[];
    for (final e in events) {
      balance += e.amountCents;
      result.add((event: e, balanceAfter: balance));
    }
    return result;
  }

  /// Categoria de despesa com maior gasto (uso em relatórios).
  List<({String name, int amount})> expensesByCategory({DateTime? month}) {
    final ref = month ?? DateTime.now();
    final start = DateHelpers.startOfMonth(ref);
    final end = DateHelpers.endOfMonth(ref);
    final map = <String, int>{};
    for (final t in transactions) {
      if (!t.isEconomicExpense) continue;
      if (DateHelpers.dateOnly(t.competenceDate).isBefore(start) ||
          DateHelpers.dateOnly(t.competenceDate).isAfter(end)) {
        continue;
      }
      final catId = t.categoryId ?? 'none';
      map[catId] = (map[catId] ?? 0) + t.amountCents;
    }
    return map.entries.map((e) {
      final cat = categories.where((c) => c.id == e.key);
      return (
        name: cat.isNotEmpty ? cat.first.name : 'Sem categoria',
        amount: e.value
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Projeção de número de meses até atingir saldo negativo (radar avançado).
  int? monthsUntilNegative() {
    for (var i = 1; i <= 24; i++) {
      final date = DateHelpers.addMonths(DateTime.now(), i);
      if (getProjectedBalance(date) < 0) return i;
    }
    return null;
  }

  /// taxa de poupança do mês (resultado / receita).
  double savingsRate() {
    final s = getMonthlySummary();
    if (s.incomeCents == 0) return 0;
    return (s.resultCents / s.incomeCents) * 100;
  }

  /// Menor saldo projetado em um período (usado no simulador).
  int minProjectedInRange(DateTime from, DateTime to) {
    return max(getLowestProjectedBalance(until: to).balance, -999999999);
  }
}
