import 'enums.dart';

/// Ativo (cap. 29).
class Asset {
  final String id;
  final String userId;
  final String name;
  final AssetType type;
  final int valueCents;
  final bool archived;
  final DateTime createdAt;

  const Asset({
    required this.id,
    required this.userId,
    required this.name,
    this.type = AssetType.other,
    required this.valueCents,
    this.archived = false,
    required this.createdAt,
  });

  Asset copyWith({String? name, AssetType? type, int? valueCents, bool? archived}) =>
      Asset(
        id: id,
        userId: userId,
        name: name ?? this.name,
        type: type ?? this.type,
        valueCents: valueCents ?? this.valueCents,
        archived: archived ?? this.archived,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'type': type.name,
        'valueCents': valueCents,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Asset.fromMap(Map<String, dynamic> m) => Asset(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: (m['name'] as String?) ?? '',
        type: AssetType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => AssetType.other,
        ),
        valueCents: (m['valueCents'] as num?)?.toInt() ?? 0,
        archived: (m['archived'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Passivo / dívida / financiamento (cap. 29/30).
class Liability {
  final String id;
  final String userId;
  final String description;
  final String creditor;
  final LiabilityType type;
  final int originalCents;
  final int outstandingCents;
  final double? interestRateMonthly;
  final int installmentsCount;
  final int currentInstallment;
  final DateTime? dueDate;
  final int monthlyPaymentCents;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Liability({
    required this.id,
    required this.userId,
    required this.description,
    this.creditor = '',
    this.type = LiabilityType.loan,
    required this.originalCents,
    required this.outstandingCents,
    this.interestRateMonthly,
    this.installmentsCount = 1,
    this.currentInstallment = 0,
    this.dueDate,
    this.monthlyPaymentCents = 0,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progress => originalCents == 0
      ? 0
      : ((originalCents - outstandingCents) / originalCents).clamp(0, 1).toDouble();

  Liability copyWith({
    String? description,
    String? creditor,
    LiabilityType? type,
    int? originalCents,
    int? outstandingCents,
    double? interestRateMonthly,
    int? installmentsCount,
    int? currentInstallment,
    DateTime? dueDate,
    int? monthlyPaymentCents,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return Liability(
      id: id,
      userId: userId,
      description: description ?? this.description,
      creditor: creditor ?? this.creditor,
      type: type ?? this.type,
      originalCents: originalCents ?? this.originalCents,
      outstandingCents: outstandingCents ?? this.outstandingCents,
      interestRateMonthly: interestRateMonthly ?? this.interestRateMonthly,
      installmentsCount: installmentsCount ?? this.installmentsCount,
      currentInstallment: currentInstallment ?? this.currentInstallment,
      dueDate: dueDate ?? this.dueDate,
      monthlyPaymentCents: monthlyPaymentCents ?? this.monthlyPaymentCents,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'description': description,
        'creditor': creditor,
        'type': type.name,
        'originalCents': originalCents,
        'outstandingCents': outstandingCents,
        'interestRateMonthly': interestRateMonthly,
        'installmentsCount': installmentsCount,
        'currentInstallment': currentInstallment,
        'dueDate': dueDate?.toIso8601String(),
        'monthlyPaymentCents': monthlyPaymentCents,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Liability.fromMap(Map<String, dynamic> m) => Liability(
        id: m['id'] as String,
        userId: m['userId'] as String,
        description: (m['description'] as String?) ?? '',
        creditor: (m['creditor'] as String?) ?? '',
        type: LiabilityType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => LiabilityType.loan,
        ),
        originalCents: (m['originalCents'] as num?)?.toInt() ?? 0,
        outstandingCents: (m['outstandingCents'] as num?)?.toInt() ?? 0,
        interestRateMonthly:
            (m['interestRateMonthly'] as num?)?.toDouble(),
        installmentsCount: (m['installmentsCount'] as num?)?.toInt() ?? 1,
        currentInstallment: (m['currentInstallment'] as num?)?.toInt() ?? 0,
        dueDate: m['dueDate'] != null
            ? DateTime.tryParse(m['dueDate'] as String)
            : null,
        monthlyPaymentCents: (m['monthlyPaymentCents'] as num?)?.toInt() ?? 0,
        archived: (m['archived'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Assinatura / gasto recorrente (cap. 31).
class Subscription {
  final String id;
  final String userId;
  final String name;
  final int amountCents;
  final RecurrenceFrequency frequency;
  final String? categoryId;
  final String? accountId;
  final String? creditCardId;
  final DateTime nextChargeDate;
  final bool active;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.userId,
    required this.name,
    required this.amountCents,
    this.frequency = RecurrenceFrequency.monthly,
    this.categoryId,
    this.accountId,
    this.creditCardId,
    required this.nextChargeDate,
    this.active = true,
    required this.createdAt,
  });

  /// Custo mensal normalizado (considera a frequência).
  int get monthlyCents {
    final f = switch (frequency) {
      RecurrenceFrequency.weekly => 52 / 12,
      RecurrenceFrequency.biweekly => 26 / 12,
      RecurrenceFrequency.monthly => 1.0,
      RecurrenceFrequency.bimonthly => 1 / 2,
      RecurrenceFrequency.quarterly => 1 / 3,
      RecurrenceFrequency.semiannual => 1 / 6,
      RecurrenceFrequency.annual => 1 / 12,
      RecurrenceFrequency.custom => 1.0,
    };
    return (amountCents * f).round();
  }

  int get annualCents => monthlyCents * 12;

  Subscription copyWith({
    String? name,
    int? amountCents,
    RecurrenceFrequency? frequency,
    String? categoryId,
    String? accountId,
    String? creditCardId,
    DateTime? nextChargeDate,
    bool? active,
  }) {
    return Subscription(
      id: id,
      userId: userId,
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      frequency: frequency ?? this.frequency,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      creditCardId: creditCardId ?? this.creditCardId,
      nextChargeDate: nextChargeDate ?? this.nextChargeDate,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'amountCents': amountCents,
        'frequency': frequency.name,
        'categoryId': categoryId,
        'accountId': accountId,
        'creditCardId': creditCardId,
        'nextChargeDate': nextChargeDate.toIso8601String(),
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Subscription.fromMap(Map<String, dynamic> m) => Subscription(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: (m['name'] as String?) ?? '',
        amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
        frequency: RecurrenceFrequency.values.firstWhere(
          (e) => e.name == m['frequency'],
          orElse: () => RecurrenceFrequency.monthly,
        ),
        categoryId: m['categoryId'] as String?,
        accountId: m['accountId'] as String?,
        creditCardId: m['creditCardId'] as String?,
        nextChargeDate:
            DateTime.tryParse((m['nextChargeDate'] as String?) ?? '') ??
                DateTime.now(),
        active: (m['active'] as bool?) ?? true,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Notificação (cap. 41).
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final InsightSeverity severity;
  final DateTime date;
  final bool read;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.severity = InsightSeverity.info,
    required this.date,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        userId: userId,
        title: title,
        message: message,
        severity: severity,
        date: date,
        read: read ?? this.read,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'message': message,
        'severity': severity.name,
        'date': date.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        userId: m['userId'] as String,
        title: (m['title'] as String?) ?? '',
        message: (m['message'] as String?) ?? '',
        severity: InsightSeverity.values.firstWhere(
          (e) => e.name == m['severity'],
          orElse: () => InsightSeverity.info,
        ),
        date: DateTime.tryParse((m['date'] as String?) ?? '') ?? DateTime.now(),
        read: (m['read'] as bool?) ?? false,
      );
}

/// Registro de auditoria (cap. 69).
class AuditLog {
  final String id;
  final String userId;
  final String action;
  final String entity;
  final String? entityId;
  final String details;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.entity,
    this.entityId,
    this.details = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'action': action,
        'entity': entity,
        'entityId': entityId,
        'details': details,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
        id: m['id'] as String,
        userId: m['userId'] as String,
        action: (m['action'] as String?) ?? '',
        entity: (m['entity'] as String?) ?? '',
        entityId: m['entityId'] as String?,
        details: (m['details'] as String?) ?? '',
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
