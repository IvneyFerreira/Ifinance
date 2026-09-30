import 'enums.dart';

/// Movimentação financeira central (cap. 59).
///
/// Diferencia datas de competência, vencimento, pagamento e criação (cap. 61).
/// Valores em CENTAVOS (cap. 60). Nunca float.
///
/// IMPORTANTE (cap. 20/62): a compra no cartão é uma DESPESA ECONÔMICA.
/// O pagamento da fatura é uma MOVIMENTAÇÃO DE CAIXA entre a conta e a
/// obrigação do cartão. O motor financeiro diferencia os dois para não
/// duplicar valores.
class Transaction {
  final String id;
  final String userId;
  final String? accountId;
  final String? categoryId;
  /// Preenchido quando a movimentação se refere a um cartão (compra/fatura).
  final String? creditCardId;
  /// Verdadeiro quando é o PAGAMENTO de uma fatura (movimentação de caixa,
  /// não despesa econômica — cap. 20).
  final bool isInvoicePayment;
  /// Mês de referência da fatura paga (para casar com a fatura do cartão).
  final DateTime? invoiceReferenceMonth;
  final TransactionType type;
  final String description;
  /// Centavos, sempre positivo; o sinal é dado por [type].
  final int amountCents;
  /// Data de competência (a que mês o valor pertence).
  final DateTime competenceDate;
  /// Data de vencimento/prevista.
  final DateTime dueDate;
  /// Data efetiva de pagamento/recebimento (null quando pendente).
  final DateTime? paidAt;
  final ExpenseStatus expenseStatus;
  final IncomeStatus incomeStatus;
  final PaymentMethod paymentMethod;
  final String notes;
  final bool isTransfer;
  /// Agrupa as duas pernas de uma transferência (cap. 17).
  final String? transferGroupId;
  /// Vínculo a compra parcelada/original (cap. 21).
  final String? purchaseId;
  /// Marcadores auxiliares.
  final bool isRecurringOccurrence;
  final String? recurringRuleId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const Transaction({
    required this.id,
    required this.userId,
    this.accountId,
    this.categoryId,
    this.creditCardId,
    this.isInvoicePayment = false,
    this.invoiceReferenceMonth,
    required this.type,
    required this.description,
    required this.amountCents,
    required this.competenceDate,
    required this.dueDate,
    this.paidAt,
    this.expenseStatus = ExpenseStatus.pending,
    this.incomeStatus = IncomeStatus.expected,
    this.paymentMethod = PaymentMethod.other,
    this.notes = '',
    this.isTransfer = false,
    this.transferGroupId,
    this.purchaseId,
    this.isRecurringOccurrence = false,
    this.recurringRuleId,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
  bool get isAdjustment => type == TransactionType.adjustment;

  /// Efeito no caixa das contas. Transferências não afetam o resultado
  /// consolidado (cap. 17) — o sinal é aplicado por conta nas duas pernas.
  /// Compras no cartão NÃO afetam o caixa até o pagamento da fatura (cap. 20).
  bool get affectsCash {
    if (isTransfer) return true; // afeta a conta individualmente
    if (isInvoicePayment) return true; // pagamento da fatura sai da conta
    if (creditCardId != null && isExpense) return false; // despesa econômica
    return true;
  }

  /// Despesa econômica: entra no resultado do mês (competência).
  /// Compras no cartão SÃO despesa econômica; pagamento de fatura NÃO é.
  bool get isEconomicExpense => isExpense && !isTransfer && !isInvoicePayment;

  bool get isPaid => paidAt != null;
  bool get isOverdue =>
      paidAt == null &&
      dueDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month,
          DateTime.now().day));

  /// Sinal do efeito econômico (para resultado): receita +, despesa -.
  int get economicSignedCents => switch (type) {
        TransactionType.income => amountCents,
        TransactionType.expense => -amountCents,
        TransactionType.adjustment => amountCents,
      };

  Transaction copyWith({
    String? accountId,
    String? categoryId,
    String? creditCardId,
    bool? isInvoicePayment,
    DateTime? invoiceReferenceMonth,
    TransactionType? type,
    String? description,
    int? amountCents,
    DateTime? competenceDate,
    DateTime? dueDate,
    DateTime? paidAt,
    bool clearPaidAt = false,
    ExpenseStatus? expenseStatus,
    IncomeStatus? incomeStatus,
    PaymentMethod? paymentMethod,
    String? notes,
    bool? isTransfer,
    String? transferGroupId,
    String? purchaseId,
    bool? isRecurringOccurrence,
    String? recurringRuleId,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return Transaction(
      id: id,
      userId: userId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      creditCardId: creditCardId ?? this.creditCardId,
      isInvoicePayment: isInvoicePayment ?? this.isInvoicePayment,
      invoiceReferenceMonth:
          invoiceReferenceMonth ?? this.invoiceReferenceMonth,
      type: type ?? this.type,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      competenceDate: competenceDate ?? this.competenceDate,
      dueDate: dueDate ?? this.dueDate,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      expenseStatus: expenseStatus ?? this.expenseStatus,
      incomeStatus: incomeStatus ?? this.incomeStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      isTransfer: isTransfer ?? this.isTransfer,
      transferGroupId: transferGroupId ?? this.transferGroupId,
      purchaseId: purchaseId ?? this.purchaseId,
      isRecurringOccurrence: isRecurringOccurrence ?? this.isRecurringOccurrence,
      recurringRuleId: recurringRuleId ?? this.recurringRuleId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'accountId': accountId,
        'categoryId': categoryId,
        'creditCardId': creditCardId,
        'isInvoicePayment': isInvoicePayment,
        'invoiceReferenceMonth': invoiceReferenceMonth?.toIso8601String(),
        'type': type.name,
        'description': description,
        'amountCents': amountCents,
        'competenceDate': competenceDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'expenseStatus': expenseStatus.name,
        'incomeStatus': incomeStatus.name,
        'paymentMethod': paymentMethod.name,
        'notes': notes,
        'isTransfer': isTransfer,
        'transferGroupId': transferGroupId,
        'purchaseId': purchaseId,
        'isRecurringOccurrence': isRecurringOccurrence,
        'recurringRuleId': recurringRuleId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  /// Tolerante a dados legados: aceita tanto os nomes atuais
  /// (`competenceDate`/`dueDate`) quanto os antigos (`date`/`time`) e nunca
  /// lança por causa de um campo com tipo inesperado — um registro assim seria
  /// descartado silenciosamente e pareceria "dados sumidos".
  factory Transaction.fromMap(Map<String, dynamic> m) {
    final id = _asString(m['id']);
    if (id == null || id.isEmpty) {
      throw const FormatException('Transaction sem id');
    }
    final comp = _parseDate(m['competenceDate']) ??
        _parseDate(m['date']) ??
        _parseDate(m['time']) ??
        DateTime.now();
    final due = _parseDate(m['dueDate']) ??
        _parseDate(m['date']) ??
        _parseDate(m['time']) ??
        comp;
    return Transaction(
      id: id,
      userId: _asString(m['userId']) ?? '',
      accountId: _asString(m['accountId']),
      categoryId: _asString(m['categoryId']),
      creditCardId: _asString(m['creditCardId']),
      isInvoicePayment: _asBool(m['isInvoicePayment']),
      invoiceReferenceMonth: _parseDate(m['invoiceReferenceMonth']),
      type: TransactionType.values.firstWhere(
        (e) => e.name == m['type'],
        orElse: () => TransactionType.expense,
      ),
      description: _asString(m['description']) ?? '',
      amountCents: _asInt(m['amountCents']),
      competenceDate: comp,
      dueDate: due,
      paidAt: _parseDate(m['paidAt']),
      expenseStatus: ExpenseStatus.values.firstWhere(
        (e) => e.name == m['expenseStatus'],
        orElse: () => ExpenseStatus.pending,
      ),
      incomeStatus: IncomeStatus.values.firstWhere(
        (e) => e.name == m['incomeStatus'],
        orElse: () => IncomeStatus.expected,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == m['paymentMethod'],
        orElse: () => PaymentMethod.other,
      ),
      notes: _asString(m['notes']) ?? '',
      isTransfer: _asBool(m['isTransfer']),
      transferGroupId: _asString(m['transferGroupId']),
      purchaseId: _asString(m['purchaseId']),
      isRecurringOccurrence: _asBool(m['isRecurringOccurrence']),
      recurringRuleId: _asString(m['recurringRuleId']),
      createdAt: _parseDate(m['createdAt']) ??
          _parseDate(m['updatedAt']) ??
          comp,
      updatedAt: _parseDate(m['updatedAt']) ?? comp,
      deleted: _asBool(m['deleted']),
    );
  }

  static String? _asString(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool _asBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) {
      if (v.isEmpty) return null;
      return DateTime.tryParse(v);
    }
    return null;
  }
}
