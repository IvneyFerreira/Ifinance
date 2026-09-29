/// Usuário e preferências. Multiusuário desde o banco inicial (cap. 53):
/// TODA informação financeira pertence a um user_id.
class AppUser {
  final String id;
  final String name;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final bool emailVerified;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted; // soft delete (cap. 69)

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    this.emailVerified = false,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? passwordHash,
    String? passwordSalt,
    bool? emailVerified,
    bool? onboardingCompleted,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      emailVerified: emailVerified ?? this.emailVerified,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'emailVerified': emailVerified,
        'onboardingCompleted': onboardingCompleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        passwordHash: (m['passwordHash'] as String?) ?? '',
        passwordSalt: (m['passwordSalt'] as String?) ?? '',
        emailVerified: (m['emailVerified'] as bool?) ?? false,
        onboardingCompleted: (m['onboardingCompleted'] as bool?) ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
        deleted: (m['deleted'] as bool?) ?? false,
      );
}

/// Modo de tema (cap. 47).
enum AppThemeMode { light, dark, system }

/// Preferências do usuário — inclui margem de segurança usada pelo
/// FinanceEngine no cálculo do Saldo Livre Seguro (cap. 65) e reservas
/// protegidas.
class UserSettings {
  final String userId;
  final AppThemeMode themeMode;
  /// Margem de segurança (%) retida no cálculo do saldo livre.
  final double safetyMarginPercent;
  /// Reservas protegidas que não entram no saldo livre seguro (emanuais).
  final int protectedReserveCents;
  /// Investimentos excluídos do saldo líquido diário (cap. 63).
  final bool excludeInvestmentsFromDailyBalance;
  /// Custo essencial mensal estimado (usado na Reserva de Emergência).
  final int essentialMonthlyCostCents;
  /// Moeda (BRL inicial).
  final String currency;

  const UserSettings({
    required this.userId,
    this.themeMode = AppThemeMode.system,
    this.safetyMarginPercent = 10,
    this.protectedReserveCents = 0,
    this.excludeInvestmentsFromDailyBalance = true,
    this.essentialMonthlyCostCents = 0,
    this.currency = 'BRL',
  });

  UserSettings copyWith({
    AppThemeMode? themeMode,
    double? safetyMarginPercent,
    int? protectedReserveCents,
    bool? excludeInvestmentsFromDailyBalance,
    int? essentialMonthlyCostCents,
    String? currency,
  }) {
    return UserSettings(
      userId: userId,
      themeMode: themeMode ?? this.themeMode,
      safetyMarginPercent: safetyMarginPercent ?? this.safetyMarginPercent,
      protectedReserveCents: protectedReserveCents ?? this.protectedReserveCents,
      excludeInvestmentsFromDailyBalance:
          excludeInvestmentsFromDailyBalance ??
              this.excludeInvestmentsFromDailyBalance,
      essentialMonthlyCostCents:
          essentialMonthlyCostCents ?? this.essentialMonthlyCostCents,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'themeMode': themeMode.name,
        'safetyMarginPercent': safetyMarginPercent,
        'protectedReserveCents': protectedReserveCents,
        'excludeInvestmentsFromDailyBalance':
            excludeInvestmentsFromDailyBalance,
        'essentialMonthlyCostCents': essentialMonthlyCostCents,
        'currency': currency,
      };

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
        userId: m['userId'] as String,
        themeMode: AppThemeMode.values.firstWhere(
          (e) => e.name == m['themeMode'],
          orElse: () => AppThemeMode.system,
        ),
        safetyMarginPercent:
            (m['safetyMarginPercent'] as num?)?.toDouble() ?? 10,
        protectedReserveCents: (m['protectedReserveCents'] as num?)?.toInt() ?? 0,
        excludeInvestmentsFromDailyBalance:
            (m['excludeInvestmentsFromDailyBalance'] as bool?) ?? true,
        essentialMonthlyCostCents:
            (m['essentialMonthlyCostCents'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? 'BRL',
      );
}
