import 'enums.dart';

/// Regra de recorrência (cap. 22). Não geramos anos de lançamentos
/// antecipadamente: usamos a regra para materializar ocorrências conforme
/// necessário (projeções, calendário, radar).
class RecurringRule {
  final String id;
  final String userId;
  final String description;
  final TransactionType type; // income | expense
  final int amountCents;
  final String? accountId;
  final String? categoryId;
  final String? creditCardId;
  final RecurrenceFrequency frequency;

  /// Intervalo em dias quando frequency == custom.
  final int customIntervalDays;
  final DateTime startDate;
  final DateTime? endDate;
  final int? totalOccurrences;

  /// Dia preferencial do mês (para mensal+). Ex.: aluguel todo dia 5.
  final int? preferredDayOfMonth;

  /// `true` quando o dia é interpretado como "N-ésimo **dia útil**" do mês
  /// (ex.: 5º dia útil — comum em salários). Quando `false`, [preferredDayOfMonth]
  /// é um dia fixo do mês; se cair em fim de semana, é ajustado para o
  /// primeiro dia útil seguinte.
  final bool useBusinessDay;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringRule({
    required this.id,
    required this.userId,
    required this.description,
    this.type = TransactionType.expense,
    required this.amountCents,
    this.accountId,
    this.categoryId,
    this.creditCardId,
    this.frequency = RecurrenceFrequency.monthly,
    this.customIntervalDays = 30,
    required this.startDate,
    this.endDate,
    this.totalOccurrences,
    this.preferredDayOfMonth,
    this.useBusinessDay = false,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  RecurringRule copyWith({
    String? description,
    TransactionType? type,
    int? amountCents,
    String? accountId,
    String? categoryId,
    String? creditCardId,
    RecurrenceFrequency? frequency,
    int? customIntervalDays,
    DateTime? startDate,
    DateTime? endDate,
    int? totalOccurrences,
    int? preferredDayOfMonth,
    bool? useBusinessDay,
    bool? active,
    DateTime? updatedAt,
  }) {
    return RecurringRule(
      id: id,
      userId: userId,
      description: description ?? this.description,
      type: type ?? this.type,
      amountCents: amountCents ?? this.amountCents,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      creditCardId: creditCardId ?? this.creditCardId,
      frequency: frequency ?? this.frequency,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalOccurrences: totalOccurrences ?? this.totalOccurrences,
      preferredDayOfMonth: preferredDayOfMonth ?? this.preferredDayOfMonth,
      useBusinessDay: useBusinessDay ?? this.useBusinessDay,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'description': description,
    'type': type.name,
    'amountCents': amountCents,
    'accountId': accountId,
    'categoryId': categoryId,
    'creditCardId': creditCardId,
    'frequency': frequency.name,
    'customIntervalDays': customIntervalDays,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'totalOccurrences': totalOccurrences,
    'preferredDayOfMonth': preferredDayOfMonth,
    'useBusinessDay': useBusinessDay,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory RecurringRule.fromMap(Map<String, dynamic> m) => RecurringRule(
    id: m['id'] as String,
    userId: m['userId'] as String,
    description: (m['description'] as String?) ?? '',
    type: TransactionType.values.firstWhere(
      (e) => e.name == m['type'],
      orElse: () => TransactionType.expense,
    ),
    amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
    accountId: m['accountId'] as String?,
    categoryId: m['categoryId'] as String?,
    creditCardId: m['creditCardId'] as String?,
    frequency: RecurrenceFrequency.values.firstWhere(
      (e) => e.name == m['frequency'],
      orElse: () => RecurrenceFrequency.monthly,
    ),
    customIntervalDays: (m['customIntervalDays'] as num?)?.toInt() ?? 30,
    startDate:
        DateTime.tryParse((m['startDate'] as String?) ?? '') ?? DateTime.now(),
    endDate: m['endDate'] != null
        ? DateTime.tryParse(m['endDate'] as String)
        : null,
    totalOccurrences: (m['totalOccurrences'] as num?)?.toInt(),
    preferredDayOfMonth: (m['preferredDayOfMonth'] as num?)?.toInt(),
    useBusinessDay: (m['useBusinessDay'] as bool?) ?? false,
    active: (m['active'] as bool?) ?? true,
    createdAt:
        DateTime.tryParse((m['createdAt'] as String?) ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse((m['updatedAt'] as String?) ?? '') ?? DateTime.now(),
  );
}
