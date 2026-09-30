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
  /// Bloqueio do app por PIN (cap. 71 - segurança).
  final bool lockEnabled;
  /// Hash do PIN (salt::pin com SHA-256 iterado). Nunca guarda o PIN em texto.
  final String pinHash;
  /// Salt do PIN.
  final String pinSalt;
  /// Autenticação em dois fatores por TOTP (app autenticador) — cap. 71.
  final bool twoFactorEnabled;
  /// Segredo TOTP em base32. Nunca exposto em texto na UI após configurado.
  final String totpSecret;
  /// Lembretes de vencimento ativados (notificações locais).
  final bool remindersEnabled;
  /// Dias de antecedência para o lembrete de vencimento.
  final int reminderDaysBefore;
  /// Desbloqueio por biometria (digital/rosto) — cap. 71.
  final bool biometricEnabled;
  /// Login sem senha por Passkey (WebAuthn/FIDO2) — cap. 71.
  final bool passkeyEnabled;
  /// Identificador estável do dispositivo usado como nome de usuário
  /// WebAuthn (armazenado no servidor Relying Party).
  final String passkeyDeviceId;

  const UserSettings({
    required this.userId,
    this.themeMode = AppThemeMode.system,
    this.safetyMarginPercent = 10,
    this.protectedReserveCents = 0,
    this.excludeInvestmentsFromDailyBalance = true,
    this.essentialMonthlyCostCents = 0,
    this.currency = 'BRL',
    this.lockEnabled = false,
    this.pinHash = '',
    this.pinSalt = '',
    this.twoFactorEnabled = false,
    this.totpSecret = '',
    this.remindersEnabled = false,
    this.reminderDaysBefore = 3,
    this.biometricEnabled = false,
    this.passkeyEnabled = false,
    this.passkeyDeviceId = '',
  });

  UserSettings copyWith({
    AppThemeMode? themeMode,
    double? safetyMarginPercent,
    int? protectedReserveCents,
    bool? excludeInvestmentsFromDailyBalance,
    int? essentialMonthlyCostCents,
    String? currency,
    bool? lockEnabled,
    String? pinHash,
    String? pinSalt,
    bool? twoFactorEnabled,
    String? totpSecret,
    bool? remindersEnabled,
    int? reminderDaysBefore,
    bool? biometricEnabled,
    bool? passkeyEnabled,
    String? passkeyDeviceId,
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
      lockEnabled: lockEnabled ?? this.lockEnabled,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      totpSecret: totpSecret ?? this.totpSecret,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      passkeyEnabled: passkeyEnabled ?? this.passkeyEnabled,
      passkeyDeviceId: passkeyDeviceId ?? this.passkeyDeviceId,
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
        'lockEnabled': lockEnabled,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'twoFactorEnabled': twoFactorEnabled,
        'totpSecret': totpSecret,
        'remindersEnabled': remindersEnabled,
        'reminderDaysBefore': reminderDaysBefore,
        'biometricEnabled': biometricEnabled,
        'passkeyEnabled': passkeyEnabled,
        'passkeyDeviceId': passkeyDeviceId,
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
        lockEnabled: (m['lockEnabled'] as bool?) ?? false,
        pinHash: (m['pinHash'] as String?) ?? '',
        pinSalt: (m['pinSalt'] as String?) ?? '',
        twoFactorEnabled: (m['twoFactorEnabled'] as bool?) ?? false,
        totpSecret: (m['totpSecret'] as String?) ?? '',
        remindersEnabled: (m['remindersEnabled'] as bool?) ?? false,
        reminderDaysBefore: (m['reminderDaysBefore'] as num?)?.toInt() ?? 3,
        biometricEnabled: (m['biometricEnabled'] as bool?) ?? false,
        passkeyEnabled: (m['passkeyEnabled'] as bool?) ?? false,
        passkeyDeviceId: (m['passkeyDeviceId'] as String?) ?? '',
      );
}
