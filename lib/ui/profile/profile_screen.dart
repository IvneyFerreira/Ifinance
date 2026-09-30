import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../accounts/accounts_screen.dart';
import '../assistant/assistant_screen.dart';
import '../budgets/budgets_screen.dart';
import '../cards/cards_screen.dart';
import '../data/data_screen.dart';
import '../recurring/recurring_screen.dart';
import '../settings/about_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/app_drawer.dart';
import '../wealth/wealth_screen.dart';

/// Perfil / Hub de módulos (cap. 6): unidades de navegação e conta.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final net = engine.getNetWorth(others: c.assets, liabilities: c.liabilities);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          FinancialCard(
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      (c.user?.name.isNotEmpty ?? false)
                          ? c.user!.name.substring(0, 1).toUpperCase()
                          : 'iF',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.user?.name ?? 'Usuário',
                          style: t.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(c.user?.email ?? '',
                          style: t.bodySmall,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            c.user?.emailVerified ?? false
                                ? Icons.verified
                                : Icons.info_outline,
                            size: 13,
                            color: c.user?.emailVerified ?? false
                                ? AppColors.positive
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c.user?.emailVerified ?? false
                                ? 'E-mail verificado'
                                : 'E-mail não verificado',
                            style: t.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinancialCard(
            gradient: LinearGradient(colors: [
              AppColors.emerald.withValues(alpha: 0.14),
              AppColors.emerald.withValues(alpha: 0.03),
            ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patrimônio líquido', style: t.bodySmall),
                const SizedBox(height: 4),
                MoneyDisplay(net.netCents, fontSize: 28, colorize: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _mini(context, 'Ativos',
                            Money.formatCompact(net.assetsCents), AppColors.positive)),
                    Expanded(
                        child: _mini(context, 'Passivos',
                            Money.formatCompact(net.liabilitiesCents), AppColors.negative)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'IFinance Assessor'),
          FinancialCard(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AssistantScreen())),
            child: Row(
              children: [
                const CircleIcon(
                    icon: Icons.auto_awesome, color: AppColors.emerald, size: 42),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Falar com o Assessor',
                          style: t.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('IA focada em despesas e entradas',
                          style: t.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.gray400),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Módulos'),
          _grid(context, [
            (Icons.account_balance_wallet_outlined, 'Contas', 'accounts'),
            (Icons.credit_card, 'Cartões', 'cards'),
            (Icons.pie_chart_outline, 'Orçamentos', 'budgets'),
            (Icons.autorenew, 'Recorrências', 'recurring'),
            (Icons.subscriptions_outlined, 'Assinaturas', 'subscriptions'),
            (Icons.savings_outlined, 'Patrimônio', 'wealth'),
            (Icons.bar_chart, 'Relatórios', 'reports'),
            (Icons.backup_outlined, 'Importar / Exportar', 'data'),
            (Icons.settings_outlined, 'Configurações', 'settings'),
            (Icons.info_outline, 'Sobre e Ajuda', 'about'),
          ]),
        ],
      ),
    );
  }

  Widget _mini(BuildContext context, String label, String value, Color color) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
        Text(value,
            style: t.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _grid(BuildContext context, List<(IconData, String, String)> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: items.map((it) {
        return FinancialCard(
          onTap: () {
            final screen = _screenFor(it.$3);
            if (screen != null) {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => screen));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleIcon(icon: it.$1, color: AppColors.emerald, size: 40),
              const SizedBox(height: 10),
              Text(it.$2,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget? _screenFor(String key) {
    switch (key) {
      case 'accounts':
        return const AccountsScreen();
      case 'cards':
        return const CardsScreen();
      case 'budgets':
        return const BudgetsScreen();
      case 'recurring':
        return const RecurringScreen();
      case 'subscriptions':
        return const SubscriptionsScreen();
      case 'wealth':
        return const WealthScreen();
      case 'reports':
        return const ReportsScreen();
      case 'data':
        return const DataScreen();
      case 'settings':
        return const SettingsScreen();
      case 'about':
        return const AboutScreen();
      default:
        return null;
    }
  }
}
