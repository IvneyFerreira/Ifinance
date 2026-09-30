import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../widgets/charts.dart';

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

/// Relatórios (cap. 35): período selecionável, comparativo entre meses,
/// despesas por categoria e exportação.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();

    final points = engine.getFlow(months: _months, end: now);
    int income = 0, expense = 0;
    for (final p in points) {
      income += p.incomeCents;
      expense += p.expenseCents;
    }
    final result = income - expense;
    final savings = income == 0 ? 0.0 : (result / income) * 100;

    final cur = engine.getMonthlySummary(now);
    final prev = engine.getMonthlySummary(DateHelpers.addMonths(now, -1));

    final start = DateHelpers.startOfMonth(
        DateHelpers.addMonths(now, -(_months - 1)));
    final end = DateHelpers.endOfMonth(now);
    final byCat = _categoryBreakdown(c, start, end);
    final catTotal = byCat.fold<int>(0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: () => _exportCsv(context, c),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          SectionHeader(title: 'Período'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Mês')),
              ButtonSegment(value: 3, label: Text('3m')),
              ButtonSegment(value: 6, label: Text('6m')),
              ButtonSegment(value: 12, label: Text('12m')),
            ],
            selected: {_months},
            onSelectionChanged: (s) => setState(() => _months = s.first),
          ),
          const SizedBox(height: 18),
          FinancialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumo de ${_periodLabel(_months)}',
                    style: t.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _stat(context, 'Entradas',
                            Money.format(income), AppColors.positive)),
                    Expanded(
                        child: _stat(context, 'Despesas',
                            Money.format(expense), AppColors.negative)),
                  ],
                ),
                const Divider(height: 26),
                Row(
                  children: [
                    Expanded(
                        child: _stat(context, 'Resultado',
                            Money.format(result),
                            result >= 0 ? AppColors.positive : AppColors.negative)),
                    Expanded(
                        child: _stat(
                            context,
                            'Taxa de poupança',
                            Money.formatPercent(savings),
                            AppColors.emerald)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Entradas x Despesas'),
          FinancialCard(
            child: IncomeExpenseChart(points: points, height: 170),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Comparativo de meses'),
          FinancialCard(
            child: Column(
              children: [
                _compareRow(context, 'Entradas', cur.incomeCents,
                    prev.incomeCents, invert: false),
                const Divider(height: 20),
                _compareRow(context, 'Despesas', cur.expenseCents,
                    prev.expenseCents, invert: true),
                const Divider(height: 20),
                _compareRow(context, 'Resultado', cur.resultCents,
                    prev.resultCents, invert: false),
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
                  final pct = catTotal == 0 ? 0.0 : (e.amount / catTotal) * 100;
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

  String _periodLabel(int m) => switch (m) {
        1 => 'este mês',
        3 => 'últimos 3 meses',
        6 => 'últimos 6 meses',
        _ => 'últimos 12 meses',
      };

  List<({String name, int amount})> _categoryBreakdown(
      AppController c, DateTime start, DateTime end) {
    final map = <String, int>{};
    for (final tx in c.transactions) {
      if (!tx.isEconomicExpense) continue;
      final d = DateHelpers.dateOnly(tx.competenceDate);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      final key = tx.categoryId ?? 'none';
      map[key] = (map[key] ?? 0) + tx.amountCents;
    }
    final list = map.entries
        .map((e) => (
              name: c.categoryById(e.key)?.name ?? 'Sem categoria',
              amount: e.value,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list.take(12).toList();
  }

  Widget _compareRow(BuildContext context, String label, int cur, int prev,
      {required bool invert}) {
    final t = Theme.of(context).textTheme;
    final diff = cur - prev;
    final pct = prev == 0 ? null : (diff / prev) * 100;
    // Para despesas, subir é ruim; para entradas/resultado, subir é bom.
    final positive = invert ? diff <= 0 : diff >= 0;
    final color = diff == 0
        ? AppColors.gray400
        : (positive ? AppColors.positive : AppColors.negative);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Money.format(cur),
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                '${diff >= 0 ? '+' : ''}${Money.format(diff)}'
                '${pct == null ? '' : ' (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%)'}',
                style: t.bodySmall?.copyWith(fontSize: 11, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall),
        const SizedBox(height: 4),
        Text(value,
            style: t.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, AppController c) async {
    final csv = c.exportTransactionsCsv();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerTheme.color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Exportar movimentações',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('ifinance-movimentacoes.csv',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.blackSoft : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      controller: sc,
                      child: SelectableText(
                        csv,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11, height: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: csv));
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        showToast(context, 'CSV copiado para a área de transferência.');
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar CSV'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
