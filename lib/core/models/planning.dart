import 'enums.dart';

/// Orçamento mensal por categoria (cap. 26).
class Budget {
  final String id;
  final String userId;
  final String categoryId;
  final int limitCents;
  final bool active;
  final DateTime createdAt;

  const Budget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.limitCents,
    this.active = true,
    required this.createdAt,
  });

  Budget copyWith({int? limitCents, bool? active}) => Budget(
        id: id,
        userId: userId,
        categoryId: categoryId,
        limitCents: limitCents ?? this.limitCents,
        active: active ?? this.active,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'categoryId': categoryId,
        'limitCents': limitCents,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as String,
        userId: m['userId'] as String,
        categoryId: m['categoryId'] as String,
        limitCents: (m['limitCents'] as num?)?.toInt() ?? 0,
        active: (m['active'] as bool?) ?? true,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Meta financeira (cap. 27/28).
class Goal {
  final String id;
  final String userId;
  final String name;
  final int targetCents;
  final int accumulatedCents;
  final DateTime? deadline;
  final GoalType type;
  /// Para reserva de emergência: meses de custo essencial desejados (cap. 28).
  final int emergencyMonths;
  final String iconName;
  final int colorValue;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetCents,
    this.accumulatedCents = 0,
    this.deadline,
    this.type = GoalType.custom,
    this.emergencyMonths = 0,
    this.iconName = 'flag',
    this.colorValue = 0xFF10B981,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progress => targetCents == 0
      ? 0
      : (accumulatedCents / targetCents).clamp(0, 10).toDouble();

  int get remainingCents =>
      (targetCents - accumulatedCents).clamp(0, targetCents);

  Goal copyWith({
    String? name,
    int? targetCents,
    int? accumulatedCents,
    DateTime? deadline,
    GoalType? type,
    int? emergencyMonths,
    String? iconName,
    int? colorValue,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id,
      userId: userId,
      name: name ?? this.name,
      targetCents: targetCents ?? this.targetCents,
      accumulatedCents: accumulatedCents ?? this.accumulatedCents,
      deadline: deadline ?? this.deadline,
      type: type ?? this.type,
      emergencyMonths: emergencyMonths ?? this.emergencyMonths,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'targetCents': targetCents,
        'accumulatedCents': accumulatedCents,
        'deadline': deadline?.toIso8601String(),
        'type': type.name,
        'emergencyMonths': emergencyMonths,
        'iconName': iconName,
        'colorValue': colorValue,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: (m['name'] as String?) ?? '',
        targetCents: (m['targetCents'] as num?)?.toInt() ?? 0,
        accumulatedCents: (m['accumulatedCents'] as num?)?.toInt() ?? 0,
        deadline: m['deadline'] != null
            ? DateTime.tryParse(m['deadline'] as String)
            : null,
        type: GoalType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => GoalType.custom,
        ),
        emergencyMonths: (m['emergencyMonths'] as num?)?.toInt() ?? 0,
        iconName: (m['iconName'] as String?) ?? 'flag',
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF10B981,
        archived: (m['archived'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Contribuição para uma meta.
class GoalContribution {
  final String id;
  final String userId;
  final String goalId;
  final int amountCents;
  final DateTime date;
  final String note;

  const GoalContribution({
    required this.id,
    required this.userId,
    required this.goalId,
    required this.amountCents,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'goalId': goalId,
        'amountCents': amountCents,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory GoalContribution.fromMap(Map<String, dynamic> m) => GoalContribution(
        id: m['id'] as String,
        userId: m['userId'] as String,
        goalId: m['goalId'] as String,
        amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
        date: DateTime.tryParse((m['date'] as String?) ?? '') ?? DateTime.now(),
        note: (m['note'] as String?) ?? '',
      );
}

/// Simulação salva (cap. 32/33).
class Simulation {
  final String id;
  final String userId;
  final String name;
  final int amountCents;
  final int installmentsCount;
  final DateTime targetDate;
  final bool viaCreditCard;
  final DateTime createdAt;

  const Simulation({
    required this.id,
    required this.userId,
    required this.name,
    required this.amountCents,
    this.installmentsCount = 1,
    required this.targetDate,
    this.viaCreditCard = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'amountCents': amountCents,
        'installmentsCount': installmentsCount,
        'targetDate': targetDate.toIso8601String(),
        'viaCreditCard': viaCreditCard,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Simulation.fromMap(Map<String, dynamic> m) => Simulation(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: (m['name'] as String?) ?? '',
        amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
        installmentsCount: (m['installmentsCount'] as num?)?.toInt() ?? 1,
        targetDate: DateTime.tryParse((m['targetDate'] as String?) ?? '') ??
            DateTime.now(),
        viaCreditCard: (m['viaCreditCard'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
