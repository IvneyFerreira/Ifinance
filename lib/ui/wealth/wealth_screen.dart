import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Patrimônio e Dívidas (cap. 29/30): ativos, passivos, patrimônio líquido.
class WealthScreen extends StatelessWidget {
  const WealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final net = engine.getNetWorth(others: c.assets, liabilities: c.liabilities);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Patrimônio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          FinancialCard(
            gradient: LinearGradient(colors: [
              AppColors.emerald.withValues(alpha: 0.16),
              AppColors.emerald.withValues(alpha: 0.03),
            ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patrimônio líquido = Ativos − Passivos',
                    style: t.bodySmall),
                const SizedBox(height: 6),
                MoneyDisplay(net.netCents, fontSize: 32, colorize: true),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _mini(context, 'Ativos',
                            net.assetsCents, AppColors.positive)),
                    Expanded(
                        child: _mini(context, 'Passivos',
                            net.liabilitiesCents, AppColors.negative)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Ativos'),
          FinancialCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final a in c.assets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleIcon(
                            icon: CategoryIcons.get('investment'),
                            color: AppColors.positive,
                            size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name,
                                  style: t.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              Text(Labels.assetType(a.type),
                                  style: t.bodySmall),
                            ],
                          ),
                        ),
                        MoneyDisplay(a.valueCents, fontSize: 14),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Passivos e Dívidas'),
          if (c.liabilities.where((l) => !l.archived).isEmpty)
            const EmptyState(
              icon: Icons.trending_down,
              title: 'Nenhuma dívida',
              message: 'Você não possui dívidas ou financiamentos cadastrados.',
            )
          else
            for (final l in c.liabilities.where((x) => !x.archived))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FinancialCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleIcon(
                              icon: Icons.trending_down,
                              color: AppColors.negative,
                              size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.description,
                                    style: t.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                Text('${l.creditor} • ${Labels.liabilityType(l.type)}',
                                    style: t.bodySmall),
                              ],
                            ),
                          ),
                          MoneyDisplay(l.outstandingCents, fontSize: 15),
                        ],
                      ),
                      const SizedBox(height: 12),
                      BudgetProgress(
                          percent: l.progress * 100, height: 6),
                      const SizedBox(height: 8),
                      Text(
                        'Parcela ${l.currentInstallment}/${l.installmentsCount} • ${Money.format(l.monthlyPaymentCents)}/mês',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _mini(BuildContext context, String label, int cents, Color color) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(Money.format(cents),
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Relatórios (cap. 35).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final byCat = engine.expensesByCategory();
    final total = byCat.fold<int>(0, (s, e) => s + e.amount);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          FinancialCard(
            child: Row(
              children: [
                Expanded(
                    child: _stat(context, 'Despesas do mês',
                        Money.format(engine.getTotalExpensesThisMonth()))),
                Expanded(
                    child: _stat(context, 'Taxa de poupança',
                        Money.formatPercent(engine.savingsRate()))),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Despesas por categoria'),
          if (byCat.isEmpty)
            const EmptyState(
              icon: Icons.bar_chart,
              title: 'Sem dados',
              message: 'Registre despesas para ver os relatórios.',
            )
          else
            FinancialCard(
              child: Column(
                children: byCat.map((e) {
                  final pct =
                      total == 0 ? 0.0 : (e.amount / total) * 100;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(e.name,
                                    style: t.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600))),
                            Text(Money.format(e.amount),
                                style: t.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 44,
                              child: Text('${pct.toStringAsFixed(0)}%',
                                  textAlign: TextAlign.right,
                                  style: t.bodySmall),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        BudgetProgress(percent: pct, color: AppColors.emerald),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
