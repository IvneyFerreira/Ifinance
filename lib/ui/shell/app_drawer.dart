import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../accounts/accounts_screen.dart';
import '../assistant/assistant_screen.dart';
import '../budgets/budgets_screen.dart';
import '../cards/cards_screen.dart';
import '../data/data_screen.dart';
import '../recurring/recurring_screen.dart';
import '../settings/about_screen.dart';
import '../settings/settings_screen.dart';
import '../wealth/wealth_screen.dart';
import 'shell_controller.dart';

/// Instala o [AppDrawer] em um `Scaffold` de tela pequena; em telas largas
/// (>= 900px) retorna `null`, pois a sidebar já faz a navegação.
AppDrawer? appDrawerFor(BuildContext context) =>
    MediaQuery.of(context).size.width >= 900 ? null : const AppDrawer();

/// Menu lateral (gaveta) do IFinance (cap. 5/6).
///
/// É o ponto de acesso CENTRAL a todas as áreas do app — inclusive o
/// Assessor IA e os módulos que antes ficavam escondidos no Perfil.
/// Aparece como gaveta em telas pequenas e como atalho de menu nas telas
/// com AppBar; em telas largas a sidebar já cumpre o papel de navegação.
///
/// Use [appDrawerFor] para instalar em um `Scaffold` respeitando o layout
/// responsivo (some no desktop, onde a sidebar já navega).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final name = (c.user?.name.isNotEmpty ?? false) ? c.user!.name : 'Usuário';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(context, name, c.user?.email ?? ''),
            _sectionLabel('Inteligência'),
            _tile(
              context,
              Icons.auto_awesome,
              'Assessor IA',
              subtitle: 'Converse com a IA sobre suas finanças',
              highlight: true,
              onTap: () => _push(context, const AssistantScreen()),
            ),
            const SizedBox(height: 6),
            _sectionLabel('Navegação'),
            _tile(context, Icons.home_outlined, 'Início',
                onTap: () => _goTab(context, 0)),
            _tile(context, Icons.swap_vert, 'Movimentações',
                onTap: () => _goTab(context, 1)),
            _tile(context, Icons.calendar_month_outlined, 'Planejar',
                onTap: () => _goTab(context, 2)),
            _tile(context, Icons.flag_outlined, 'Metas',
                onTap: () => _goTab(context, 3)),
            _tile(context, Icons.person_outline, 'Perfil',
                onTap: () => _goTab(context, 4)),
            const SizedBox(height: 6),
            _sectionLabel('Ferramentas'),
            _tile(context, Icons.account_balance_wallet_outlined, 'Contas',
                onTap: () => _push(context, const AccountsScreen())),
            _tile(context, Icons.credit_card, 'Cartões',
                onTap: () => _push(context, const CardsScreen())),
            _tile(context, Icons.pie_chart_outline, 'Orçamentos',
                onTap: () => _push(context, const BudgetsScreen())),
            _tile(context, Icons.autorenew, 'Recorrências',
                onTap: () => _push(context, const RecurringScreen())),
            _tile(context, Icons.subscriptions_outlined, 'Assinaturas',
                onTap: () => _push(context, const SubscriptionsScreen())),
            _tile(context, Icons.savings_outlined, 'Patrimônio',
                onTap: () => _push(context, const WealthScreen())),
            _tile(context, Icons.bar_chart, 'Relatórios',
                onTap: () => _push(context, const ReportsScreen())),
            _tile(context, Icons.backup_outlined, 'Importar / Exportar',
                onTap: () => _push(context, const DataScreen())),
            const Divider(height: 24, indent: 20, endIndent: 20),
            _tile(context, Icons.settings_outlined, 'Configurações',
                onTap: () => _push(context, const SettingsScreen())),
            _tile(context, Icons.info_outline, 'Sobre e Ajuda',
                onTap: () => _push(context, const AboutScreen())),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- helpers

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context); // fecha a gaveta
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _goTab(BuildContext context, int index) {
    Navigator.pop(context);
    context.read<ShellController>().select(index);
  }

  Widget _header(BuildContext context, String name, String email) {
    final t = Theme.of(context).textTheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'iF';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IFinance',
                        style: t.titleMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'Sua vida financeira sob controle',
                      style: t.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name,
              style: t.bodyMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (email.isNotEmpty)
            Text(email,
                style: t.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    bool highlight = false,
    required VoidCallback onTap,
  }) {
    final t = Theme.of(context).textTheme;
    final fg = highlight ? AppColors.emerald : t.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: highlight
            ? AppColors.emerald.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 21, color: fg),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: t.bodyMedium?.copyWith(
                            fontWeight:
                                highlight ? FontWeight.w700 : FontWeight.w600,
                            color: highlight ? AppColors.emerald : null,
                          )),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle,
                              style: t.bodySmall?.copyWith(fontSize: 11)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: AppColors.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
