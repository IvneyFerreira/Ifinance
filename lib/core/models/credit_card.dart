import 'enums.dart';

/// Cartão de crédito (cap. 18).
class CreditCard {
  final String id;
  final String userId;
  final String name;
  final String institution;
  final CardBrand brand;
  final String lastDigits;
  final int limitCents;
  /// Dia de fechamento da fatura (1..31).
  final int closingDay;
  /// Dia de vencimento da fatura (1..31).
  final int dueDay;
  final int colorValue;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditCard({
    required this.id,
    required this.userId,
    required this.name,
    this.institution = '',
    this.brand = CardBrand.other,
    this.lastDigits = '',
    this.limitCents = 0,
    this.closingDay = 1,
    this.dueDay = 10,
    this.colorValue = 0xFF6366F1,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CreditCard copyWith({
    String? name,
    String? institution,
    CardBrand? brand,
    String? lastDigits,
    int? limitCents,
    int? closingDay,
    int? dueDay,
    int? colorValue,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return CreditCard(
      id: id,
      userId: userId,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      brand: brand ?? this.brand,
      lastDigits: lastDigits ?? this.lastDigits,
      limitCents: limitCents ?? this.limitCents,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
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
        'institution': institution,
        'brand': brand.name,
        'lastDigits': lastDigits,
        'limitCents': limitCents,
        'closingDay': closingDay,
        'dueDay': dueDay,
        'colorValue': colorValue,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CreditCard.fromMap(Map<String, dynamic> m) => CreditCard(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: (m['name'] as String?) ?? '',
        institution: (m['institution'] as String?) ?? '',
        brand: CardBrand.values.firstWhere(
          (e) => e.name == m['brand'],
          orElse: () => CardBrand.other,
        ),
        lastDigits: (m['lastDigits'] as String?) ?? '',
        limitCents: (m['limitCents'] as num?)?.toInt() ?? 0,
        closingDay: (m['closingDay'] as num?)?.toInt() ?? 1,
        dueDay: (m['dueDay'] as num?)?.toInt() ?? 10,
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF6366F1,
        archived: (m['archived'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Compra no cartão (cap. 20/21). Despesa econômica, vinculada a uma compra
/// original quando parcelada.
class CardPurchase {
  final String id;
  final String userId;
  final String creditCardId;
  final String? categoryId;
  final String description;
  final int totalCents;
  final int installmentsCount;
  /// Mês de referência da 1ª parcela (primeiro dia do mês).
  final DateTime firstReferenceMonth;
  final DateTime createdAt;

  const CardPurchase({
    required this.id,
    required this.userId,
    required this.creditCardId,
    this.categoryId,
    required this.description,
    required this.totalCents,
    required this.installmentsCount,
    required this.firstReferenceMonth,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'creditCardId': creditCardId,
        'categoryId': categoryId,
        'description': description,
        'totalCents': totalCents,
        'installmentsCount': installmentsCount,
        'firstReferenceMonth': firstReferenceMonth.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory CardPurchase.fromMap(Map<String, dynamic> m) => CardPurchase(
        id: m['id'] as String,
        userId: m['userId'] as String,
        creditCardId: m['creditCardId'] as String,
        categoryId: m['categoryId'] as String?,
        description: (m['description'] as String?) ?? '',
        totalCents: (m['totalCents'] as num?)?.toInt() ?? 0,
        installmentsCount: (m['installmentsCount'] as num?)?.toInt() ?? 1,
        firstReferenceMonth:
            DateTime.tryParse((m['firstReferenceMonth'] as String?) ?? '') ??
                DateTime.now(),
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Parcela (cap. 21). Cada parcela pertence à respectiva fatura e permanece
/// vinculada à compra original.
class Installment {
  final String id;
  final String userId;
  final String purchaseId;
  final String creditCardId;
  final int number; // 1..N
  final int totalCount;
  final int amountCents;
  /// Mês de referência da fatura.
  final DateTime referenceMonth;
  final bool paid;
  final DateTime createdAt;

  const Installment({
    required this.id,
    required this.userId,
    required this.purchaseId,
    required this.creditCardId,
    required this.number,
    required this.totalCount,
    required this.amountCents,
    required this.referenceMonth,
    this.paid = false,
    required this.createdAt,
  });

  Installment copyWith({bool? paid}) => Installment(
        id: id,
        userId: userId,
        purchaseId: purchaseId,
        creditCardId: creditCardId,
        number: number,
        totalCount: totalCount,
        amountCents: amountCents,
        referenceMonth: referenceMonth,
        paid: paid ?? this.paid,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'purchaseId': purchaseId,
        'creditCardId': creditCardId,
        'number': number,
        'totalCount': totalCount,
        'amountCents': amountCents,
        'referenceMonth': referenceMonth.toIso8601String(),
        'paid': paid,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Installment.fromMap(Map<String, dynamic> m) => Installment(
        id: m['id'] as String,
        userId: m['userId'] as String,
        purchaseId: m['purchaseId'] as String,
        creditCardId: m['creditCardId'] as String,
        number: (m['number'] as num?)?.toInt() ?? 1,
        totalCount: (m['totalCount'] as num?)?.toInt() ?? 1,
        amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
        referenceMonth:
            DateTime.tryParse((m['referenceMonth'] as String?) ?? '') ??
                DateTime.now(),
        paid: (m['paid'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Status da fatura.
enum InvoiceStatus { open, closed, paid, overdue }

/// Fatura do cartão (cap. 19).
class Invoice {
  final String id;
  final String userId;
  final String creditCardId;
  final DateTime referenceMonth; // primeiro dia do mês
  final DateTime closingDate;
  final DateTime dueDate;
  final int totalCents;
  final DateTime? paidAt;
  final InvoiceStatus status;

  const Invoice({
    required this.id,
    required this.userId,
    required this.creditCardId,
    required this.referenceMonth,
    required this.closingDate,
    required this.dueDate,
    this.totalCents = 0,
    this.paidAt,
    this.status = InvoiceStatus.open,
  });

  Invoice copyWith({
    int? totalCents,
    DateTime? paidAt,
    bool clearPaidAt = false,
    InvoiceStatus? status,
  }) =>
      Invoice(
        id: id,
        userId: userId,
        creditCardId: creditCardId,
        referenceMonth: referenceMonth,
        closingDate: closingDate,
        dueDate: dueDate,
        totalCents: totalCents ?? this.totalCents,
        paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'creditCardId': creditCardId,
        'referenceMonth': referenceMonth.toIso8601String(),
        'closingDate': closingDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'totalCents': totalCents,
        'paidAt': paidAt?.toIso8601String(),
        'status': status.name,
      };

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
        id: m['id'] as String,
        userId: m['userId'] as String,
        creditCardId: m['creditCardId'] as String,
        referenceMonth:
            DateTime.tryParse((m['referenceMonth'] as String?) ?? '') ??
                DateTime.now(),
        closingDate: DateTime.tryParse((m['closingDate'] as String?) ?? '') ??
            DateTime.now(),
        dueDate: DateTime.tryParse((m['dueDate'] as String?) ?? '') ??
            DateTime.now(),
        totalCents: (m['totalCents'] as num?)?.toInt() ?? 0,
        paidAt: m['paidAt'] != null
            ? DateTime.tryParse(m['paidAt'] as String)
            : null,
        status: InvoiceStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => InvoiceStatus.open,
        ),
      );
}
