import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../auth/two_factor_setup_screen.dart';
import 'categories_screen.dart';

/// Configurações (cap. 6/47/71/72): tema, margem de segurança, reserva;
/// verificação de e-mail; exportação; exclusão de conta.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final s = c.settings;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          SectionHeader(title: 'Aparência'),
          FinancialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tema', style: t.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _themeChip(context, c, AppThemeMode.light, 'Claro', Icons.light_mode),
                    _themeChip(context, c, AppThemeMode.dark, 'Escuro', Icons.dark_mode),
                    _themeChip(context, c, AppThemeMode.system, 'Automático', Icons.brightness_auto),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Motor financeiro'),
          FinancialCard(
            child: Column(
              children: [
                _row(
                  context,
                  'Margem de segurança',
                  '${s.safetyMarginPercent.toStringAsFixed(0)}%',
                  onTap: () => _editMargin(context, c, s),
                ),
                const Divider(height: 20),
                _row(
                  context,
                  'Reservas protegidas',
                  Money.format(s.protectedReserveCents),
                  onTap: () => _editReserve(context, c, s),
                ),
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Excluir investimentos do saldo diário'),
                  value: s.excludeInvestmentsFromDailyBalance,
                  onChanged: (v) => c.updateSettings(
                      s.copyWith(excludeInvestmentsFromDailyBalance: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Moeda e formato'),
          FinancialCard(
            child: _row(
              context,
              'Moeda',
              _currencyLabel(s.currency),
              onTap: () => _editCurrency(context, c, s),
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Categorias'),
          FinancialCard(
            child: _row(context, 'Gerenciar categorias', 'Editar',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Segurança'),
          FinancialCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bloqueio por PIN'),
                  subtitle: Text(s.lockEnabled
                      ? 'Protege o app ao abrir'
                      : 'Peça um PIN para abrir o app'),
                  value: s.lockEnabled,
                  onChanged: (v) => _toggleLock(context, c, s, v),
                ),
                if (s.lockEnabled) ...[
                  const Divider(height: 20),
                  _row(context, 'Alterar PIN', 'Trocar',
                      onTap: () => _setPin(context, c, changing: true)),
                  const Divider(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_clock, color: AppColors.emerald),
                    title: const Text('Bloquear agora'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => c.lockNow(),
                  ),
                ],
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desbloqueio por biometria'),
                  subtitle: Text(s.biometricEnabled
                      ? 'Use digital ou rosto para abrir'
                      : 'Requer o bloqueio por PIN ativo'),
                  value: s.biometricEnabled,
                  onChanged: s.lockEnabled
                      ? (v) => _toggleBiometric(context, c, v)
                      : null,
                ),
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Autenticação em 2 fatores'),
                  subtitle: Text(s.twoFactorEnabled
                      ? 'Ativa (app autenticador)'
                      : 'Proteja o login com um código temporário'),
                  value: s.twoFactorEnabled,
                  onChanged: (v) => _toggleTwoFactor(context, c, v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Lembretes'),
          FinancialCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lembretes de vencimento'),
                  subtitle: const Text(
                      'Avisa sobre contas a vencer e vencidas'),
                  value: s.remindersEnabled,
                  onChanged: (v) =>
                      c.setReminders(enabled: v).then((_) {
                    if (v && context.mounted) {
                      showToast(context, 'Lembretes ativados.');
                    }
                  }),
                ),
                if (s.remindersEnabled) ...[
                  const Divider(height: 20),
                  _row(
                    context,
                    'Avisar com antecedência',
                    '${s.reminderDaysBefore} dia(s)',
                    onTap: () => _editReminderDays(context, c, s),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Conta'),
          FinancialCard(
            child: Column(
              children: [
                if (!(c.user?.emailVerified ?? false))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mark_email_unread_outlined,
                        color: AppColors.warning),
                    title: const Text('Verificar e-mail'),
                    subtitle: const Text('Confirme seu endereço de e-mail'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.read<AppController>().verifyEmailNow();
                      if (context.mounted) {
                        showToast(context, 'E-mail verificado.');
                      }
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: AppColors.negative),
                  title: const Text('Sair da conta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final controller = context.read<AppController>();
                    final ok = await showConfirmDialog(context,
                        title: 'Sair da conta',
                        message: 'Deseja sair? Seus dados permanecem salvos.');
                    if (ok) await controller.logout();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.restart_alt, color: AppColors.warning),
                  title: const Text('Redefinir dados financeiros'),
                  subtitle: const Text('Apaga lançamentos e recomeça do zero'),
                  onTap: () async {
                    final controller = context.read<AppController>();
                    final ok = await showConfirmDialog(context,
                        title: 'Redefinir dados',
                        message:
                            'Isso removerá contas, movimentações, cartões e metas, recriando categorias padrão. Sua conta de acesso é mantida.',
                        confirmLabel: 'Redefinir',
                        destructive: true);
                    if (ok) {
                      await controller.resetFinancialData();
                      if (context.mounted) {
                        showToast(context, 'Dados redefinidos.');
                      }
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.delete_forever, color: AppColors.negative),
                  title: const Text('Excluir conta e dados'),
                  subtitle: const Text('Ação permanente e irreversível'),
                  onTap: () async {
                    final controller = context.read<AppController>();
                    final ok = await showConfirmDialog(context,
                        title: 'Excluir conta',
                        message:
                            'Isso removerá permanentemente todos os seus dados financeiros. Deseja continuar?',
                        confirmLabel: 'Excluir tudo',
                        destructive: true);
                    if (ok) await controller.deleteAccount();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text('IFinance 1.0 • ${s.currency}',
                style: t.bodySmall),
          ),
        ],
      ),
    );
  }

  void _toggleLock(
      BuildContext context, AppController c, UserSettings s, bool value) {
    if (value) {
      _setPin(context, c);
    } else {
      c.disablePin();
      showToast(context, 'Bloqueio desativado.');
    }
  }

  void _setPin(BuildContext context, AppController c, {bool changing = false}) {
    final pinCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(changing ? 'Alterar PIN' : 'Definir PIN',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Use de 4 a 6 dígitos.', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: pinCtrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'PIN', counterText: ''),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final pin = pinCtrl.text;
                    if (pin.length < 4) {
                      showToast(ctx, 'O PIN deve ter ao menos 4 dígitos.',
                          error: true);
                      return;
                    }
                    await c.setPin(pin);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      showToast(context, 'PIN configurado.');
                    }
                  },
                  child: const Text('Salvar PIN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBiometric(
      BuildContext context, AppController c, bool value) async {
    if (value) {
      final avail = await c.biometricAvailable();
      if (!context.mounted) return;
      if (!avail) {
        showToast(context,
            'Biometria indisponível neste dispositivo. Use o PIN.',
            error: true);
        return;
      }
    }
    final ok = await c.setBiometric(value);
    if (!context.mounted) return;
    if (value && !ok) {
      showToast(context, 'Não foi possível confirmar a biometria.', error: true);
    } else {
      showToast(context,
          value ? 'Desbloqueio biométrico ativado.' : 'Biometria desativada.');
    }
  }

  void _toggleTwoFactor(BuildContext context, AppController c, bool value) {    if (value) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TwoFactorSetupScreen()),
      );
    } else {
      showConfirmDialog(
        context,
        title: 'Desativar 2FA',
        message:
            'Sem a verificação em duas etapas, sua conta fica menos protegida. Deseja continuar?',
        confirmLabel: 'Desativar',
        destructive: true,
      ).then((ok) async {
        if (!context.mounted) return;
        if (ok) {
          await c.disableTwoFactor();
          if (context.mounted) showToast(context, '2FA desativado.');
        }
      });
    }
  }

  void _editReminderDays(
      BuildContext context, AppController c, UserSettings s) {
    int value = s.reminderDaysBefore;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Antecedência do lembrete',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      'Quantos dias antes do vencimento você quer ser avisado.',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Text('$value dia(s)',
                      style: Theme.of(ctx)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Slider(
                    value: value.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$value',
                    onChanged: (v) => setSheet(() => value = v.round()),
                  ),
                  FilledButton(
                    onPressed: () {
                      c.setReminders(daysBefore: value);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  String _currencyLabel(String code) {
    switch (code) {
      case 'BRL':
        return 'Real (R\$)';
      case 'USD':
        return 'Dólar (US\$)';
      case 'EUR':
        return 'Euro (€)';
      default:
        return code;
    }
  }

  void _editCurrency(BuildContext context, AppController c, UserSettings s) {
    const options = <(String, String, String)>[
      ('BRL', 'Real brasileiro', 'R\$'),
      ('USD', 'Dólar americano', 'US\$'),
      ('EUR', 'Euro', '€'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moeda',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ...options.map((o) {
                  final selected = s.currency == o.$1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                      child: Text(o.$3,
                          style: const TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w800)),
                    ),
                    title: Text(o.$2),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.emerald)
                        : null,
                    onTap: () {
                      c.updateSettings(s.copyWith(currency: o.$1));
                      Money.setSymbol(o.$3);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themeChip(BuildContext context, AppController c, AppThemeMode mode,
      String label, IconData icon) {
    final selected = c.themeMode == mode;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 16, color: selected ? Colors.white : null),
      label: Text(label),
      selected: selected,
      onSelected: (_) => c.setThemeMode(mode),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium)),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  void _editMargin(BuildContext context, AppController c, UserSettings s) {
    double value = s.safetyMarginPercent;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Margem de segurança',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      'Percentual do saldo retido no cálculo do Saldo Livre Seguro.',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Text('${value.toStringAsFixed(0)}%',
                      style: Theme.of(ctx)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Slider(
                    value: value,
                    min: 0,
                    max: 40,
                    divisions: 40,
                    label: '${value.toStringAsFixed(0)}%',
                    onChanged: (v) => setSheet(() => value = v),
                  ),
                  FilledButton(
                    onPressed: () {
                      c.updateSettings(s.copyWith(safetyMarginPercent: value));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _editReserve(BuildContext context, AppController c, UserSettings s) {
    final controller =
        TextEditingController(text: Money.formatPlain(s.protectedReserveCents));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reservas protegidas',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      'Valor que não deve ser considerado como disponível para gastar.',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      final cents = Money.parse(controller.text) ?? 0;
                      c.updateSettings(s.copyWith(protectedReserveCents: cents));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
