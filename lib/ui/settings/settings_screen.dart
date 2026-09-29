import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

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
                    final ok = await showConfirmDialog(context,
                        title: 'Sair da conta',
                        message: 'Deseja sair? Seus dados permanecem salvos.');
                    if (ok) await context.read<AppController>().logout();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.delete_forever, color: AppColors.negative),
                  title: const Text('Excluir conta e dados'),
                  subtitle: const Text('Ação permanente e irreversível'),
                  onTap: () async {
                    final ok = await showConfirmDialog(context,
                        title: 'Excluir conta',
                        message:
                            'Isso removerá permanentemente todos os seus dados financeiros. Deseja continuar?',
                        confirmLabel: 'Excluir tudo',
                        destructive: true);
                    if (ok) await context.read<AppController>().deleteAccount();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text('NeyFlow 1.0 • ${s.currency}',
                style: t.bodySmall),
          ),
        ],
      ),
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
