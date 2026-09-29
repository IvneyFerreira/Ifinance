import 'enums.dart';

/// Conta financeira (cap. 16).
class Account {
  final String id;
  final String userId;
  final String name;
  final String institution;
  final AccountType type;
  /// Saldo informado/reconciliado em centavos (cap. 63/70).
  final int balanceCents;
  final int colorValue;
  final bool includeInNetWorth;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    this.institution = '',
    this.type = AccountType.checking,
    this.balanceCents = 0,
    this.colorValue = 0xFF10B981,
    this.includeInNetWorth = true,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Account copyWith({
    String? name,
    String? institution,
    AccountType? type,
    int? balanceCents,
    int? colorValue,
    bool? includeInNetWorth,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      type: type ?? this.type,
      balanceCents: balanceCents ?? this.balanceCents,
      colorValue: colorValue ?? this.colorValue,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
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
        'type': type.name,
        'balanceCents': balanceCents,
        'colorValue': colorValue,
        'includeInNetWorth': includeInNetWorth,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: (m['name'] as String?) ?? '',
        institution: (m['institution'] as String?) ?? '',
        type: AccountType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => AccountType.checking,
        ),
        balanceCents: (m['balanceCents'] as num?)?.toInt() ?? 0,
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF10B981,
        includeInNetWorth: (m['includeInNetWorth'] as bool?) ?? true,
        archived: (m['archived'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Categoria (cap. 40). Suporta subcategorias via parentId.
class Category {
  final String id;
  final String userId;
  final String name;
  final String? parentId;
  final String iconName;
  final int colorValue;
  final bool isIncome;
  final bool archived;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    this.parentId,
    this.iconName = 'category',
    this.colorValue = 0xFF6B7280,
    this.isIncome = false,
    this.archived = false,
    required this.createdAt,
  });

  Category copyWith({
    String? name,
    String? parentId,
    String? iconName,
    int? colorValue,
    bool? isIncome,
    bool? archived,
  }) {
    return Category(
      id: id,
      userId: userId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      isIncome: isIncome ?? this.isIncome,
      archived: archived ?? this.archived,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'parentId': parentId,
        'iconName': iconName,
        'colorValue': colorValue,
        'isIncome': isIncome,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: (m['name'] as String?) ?? '',
        parentId: m['parentId'] as String?,
        iconName: (m['iconName'] as String?) ?? 'category',
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF6B7280,
        isIncome: (m['isIncome'] as bool?) ?? false,
        archived: (m['archived'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
