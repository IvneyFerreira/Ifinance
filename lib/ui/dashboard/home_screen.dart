import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/finance/finance_engine.dart';
import '../../core/finance/finance_models.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/app_drawer.dart';
import '../shell/quick_add.dart';
import '../wealth/wealth_screen.dart';
import '../widgets/charts.dart';

/// Home / Dashboard (cap. 7, 8, 9, 11, 12, 87).
/// Compreensível em ~5 segundos (cap. 3): Saldo Livre Seguro em destaque,
/// seletor de horizonte, resumo do mês, radar e próximos eventos.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Horizon _horizon = Horizon.month;
  int _flowMonths = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final dashboard = engine.buildDashboard(_horizon);

    return Scaffold(
      drawer: appDrawerFor(context),
      body: Builder(
        builder: (context) => SafeArea(
          child: RefreshIndicator(
            color: AppColors.emerald,
            onRefresh: () => c.refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _greeting(context, c),
                const SizedBox(height: 20),
                _safeAvailableBlock(context, engine, dashboard),
                const SizedBox(height: 16),
                _investSuggestion(context, engine),
                const SizedBox(height: 16),
                _horizonSelector(),
                const SizedBox(height: 16),
                _monthSummaryCard(context, dashboard.monthSummary),
                const SizedBox(height: 22),
                _flowSection(context, engine),
                const SizedBox(height: 22),
                SectionHeader(title: 'Radar Financeiro'),
                _radarCard(context, dashboard.radar),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Próximos movimentos',
                  actionLabel: 'Timeline',
                  onAction: () => _openTimeline(context, engine),
                ),
                _upcomingEvents(context, engine),
                const SizedBox(height: 22),
                SectionHeader(title: 'Orçamentos'),
                _budgets(context, c, engine),
                const SizedBox(height: 22),
                SectionHeader(title: 'Metas'),
                _goals(context, c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _greeting(BuildContext context, AppController c) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
        ? 'Boa tarde'
        : 'Boa noite';
    final name = c.user?.name.split(' ').first ?? '';
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        if (MediaQuery.of(context).size.width < 900)
          IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name.',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                DateHelpers.monthYear.format(DateTime.now()),
                style: t.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _openNotifications(context, c),
          icon: Badge(
            isLabelVisible: c.unreadNotifications > 0,
            label: Text('${c.unreadNotifications}'),
            backgroundColor: AppColors.negative,
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }

  Widget _safeAvailableBlock(
    BuildContext context,
    FinanceEngine engine,
    DashboardData d,
  ) {
    final t = Theme.of(context).textTheme;
    final positive = d.safeAvailableCents >= 0;
    return FinancialCard(
      padding: const EdgeInsets.all(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.emerald.withValues(alpha: 0.16),
          AppColors.emerald.withValues(alpha: 0.03),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Seu dinheiro hoje',
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              InkWell(
                onTap: () => showCalcExplanation(
                  context,
                  engine.explainSafeAvailable(until: _horizonEnd(engine)),
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: t.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text('Ver cálculo', style: t.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MoneyDisplay(
            d.safeAvailableCents,
            fontSize: 40,
            fontWeight: FontWeight.w800,
          ),
          Text(
            'Livre seguro',
            style: t.bodySmall?.copyWith(color: t.bodySmall?.color),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  context,
                  'Saldo em contas',
                  d.currentBalanceCents,
                  Icons.account_balance_wallet_outlined,
                  onTap: () => showCalcExplanation(
                    context,
                    CalcExplanation(
                      title: 'Saldo em contas',
                      components: engine.accounts
                          .map((a) => CalcComponent(a.name, a.balanceCents))
                          .toList(),
                      resultCents: d.currentBalanceCents,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: Theme.of(context).dividerTheme.color,
              ),
              Expanded(
                child: _miniMetric(
                  context,
                  'Comprometido',
                  d.committedCents,
                  Icons.lock_clock,
                  color: AppColors.warning,
                  onTap: () => showCalcExplanation(
                    context,
                    engine.explainSafeAvailable(until: _horizonEnd(engine)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: positive ? AppColors.positive : AppColors.negative,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Projeção do mês: ${Money.format(d.projectedMonthEndCents)}',
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime _horizonEnd(FinanceEngine e) => e.horizonEndDate(_horizon);

  /// Sugestão de quanto investir por mês (cap. 63).
  Widget _investSuggestion(BuildContext context, FinanceEngine engine) {
    final t = Theme.of(context).textTheme;
    final suggested = engine.suggestedMonthlyInvestment();
    if (suggested <= 0) return const SizedBox.shrink();
    final range = engine.suggestedInvestmentRange();
    return FinancialCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const WealthScreen())),
      child: Row(
        children: [
          const CircleIcon(
            icon: Icons.trending_up,
            color: AppColors.emerald,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sugestão de investimento',
                    style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    MoneyDisplay(suggested, fontSize: 22, colorize: false),
                    const SizedBox(width: 6),
                    Text('/mês', style: t.bodySmall),
                  ],
                ),
                Text(
                  'Faixa ideal: ${Money.formatCompact(range.$1)} a ${Money.formatCompact(range.$2)}',
                  style: t.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray400),
        ],
      ),
    );
  }

  Widget _miniMetric(
    BuildContext context,
    String label,
    int cents,
    IconData icon, {
    Color? color,
    VoidCallback? onTap,
  }) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color ?? t.bodySmall?.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: t.bodySmall?.copyWith(
                      color: color ?? t.bodySmall?.color,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            MoneyDisplay(cents, fontSize: 17, colorize: false),
          ],
        ),
      ),
    );
  }

  Widget _horizonSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.gray100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: Horizon.values.map((h) {
          final selected = _horizon == h;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _horizon = h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCard
                            : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  h.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.emerald
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _monthSummaryCard(BuildContext context, MonthlySummary s) {
    final t = Theme.of(context).textTheme;
    return FinancialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateHelpers.monthLabel(s.month),
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              StatusBadge(
                label:
                    '${Money.formatPercent(s.committedPercent)} comprometido',
                color: s.committedPercent > 90
                    ? AppColors.negative
                    : s.committedPercent > 75
                    ? AppColors.warning
                    : AppColors.positive,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _monthMetric(
                  context,
                  'Entrou',
                  s.incomeCents,
                  AppColors.positive,
                ),
              ),
              Expanded(
                child: _monthMetric(
                  context,
                  'Saiu',
                  s.expenseCents,
                  AppColors.negativeSoft,
                ),
              ),
              Expanded(
                child: _monthMetric(
                  context,
                  'Resultado',
                  s.resultCents,
                  s.resultCents >= 0 ? AppColors.positive : AppColors.negative,
                  signed: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthMetric(
    BuildContext context,
    String label,
    int cents,
    Color color, {
    bool signed = false,
  }) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall),
        const SizedBox(height: 4),
        MoneyDisplay(cents, fontSize: 15, color: color, signed: signed),
      ],
    );
  }

  Widget _flowSection(BuildContext context, FinanceEngine engine) {
    final points = engine.getFlow(months: _flowMonths);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Meu mês', trailing: _flowSelector()),
        FinancialCard(
          child: Column(
            children: [
              Row(
                children: [
                  _legend(context, 'Receitas', AppColors.positive),
                  const SizedBox(width: 16),
                  _legend(context, 'Despesas', AppColors.negativeSoft),
                ],
              ),
              const SizedBox(height: 14),
              IncomeExpenseChart(points: points),
            ],
          ),
        ),
      ],
    );
  }

  Widget _flowSelector() {
    final options = [1, 6, 12];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.gray100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: options.map((o) {
          final selected = _flowMonths == o;
          return GestureDetector(
            onTap: () => setState(() => _flowMonths = o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? AppColors.emerald : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                o == 1 ? 'Mês' : '${o}m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _legend(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _radarCard(BuildContext context, RadarData radar) {
    final t = Theme.of(context).textTheme;
    return FinancialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _radarStat(
                  context,
                  'Este mês',
                  '${radar.paymentsCount} contas a pagar',
                  Icons.event_note_outlined,
                  AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _radarStat(
                  context,
                  'Para pagar',
                  Money.format(radar.paymentsCents),
                  Icons.arrow_upward,
                  AppColors.negativeSoft,
                ),
              ),
              Expanded(
                child: _radarStat(
                  context,
                  'Para receber',
                  Money.format(radar.receiptsCents),
                  Icons.arrow_downward,
                  AppColors.positive,
                ),
              ),
            ],
          ),
          if (radar.nextIncomeDate != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.positive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    size: 16,
                    color: AppColors.positive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Próxima entrada: ${Money.format(radar.nextIncomeCents)} • ${DateHelpers.dayMonth.format(radar.nextIncomeDate!)}',
                    style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          if (radar.insights.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...radar.insights.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _insightRow(context, i),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _radarStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
            Text(
              value,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _insightRow(BuildContext context, Insight i) {
    final color = switch (i.severity) {
      InsightSeverity.positive => AppColors.positive,
      InsightSeverity.info => AppColors.info,
      InsightSeverity.warning => AppColors.warning,
      InsightSeverity.critical => AppColors.negative,
    };
    final icon = switch (i.severity) {
      InsightSeverity.positive => Icons.check_circle_outline,
      InsightSeverity.info => Icons.info_outline,
      InsightSeverity.warning => Icons.warning_amber_rounded,
      InsightSeverity.critical => Icons.error_outline,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            i.message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _upcomingEvents(BuildContext context, FinanceEngine engine) {
    final events = engine.upcomingEvents(limit: 5);
    if (events.isEmpty) {
      return FinancialCard(
        onTap: () => showQuickAdd(context),
        child: Row(
          children: [
            const Icon(Icons.waves, color: AppColors.emerald),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhum movimento previsto. Tudo tranquilo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final timeline = engine.timeline(days: 60).take(5).toList();
    return FinancialCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < timeline.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateHelpers.friendly(timeline[i].event.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 140,
                        child: Text(
                          timeline[i].event.label,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyDisplay(
                        timeline[i].event.amountCents,
                        fontSize: 15,
                        colorize: true,
                        signed: true,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Saldo ${Money.format(timeline[i].balanceAfter)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (i != timeline.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _budgets(BuildContext context, AppController c, FinanceEngine engine) {
    final usage = engine.getBudgetUsage(c.budgets).take(5).toList();
    if (usage.isEmpty) {
      return FinancialCard(
        child: Text(
          'Nenhum orçamento definido ainda.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return FinancialCard(
      child: Column(
        children: usage.map((u) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        u.categoryName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${u.percent.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${Money.format(u.consumedCents)} / ${Money.format(u.limitCents)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                BudgetProgress(percent: u.percent),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _goals(BuildContext context, AppController c) {
    final goals = c.goals.where((g) => !g.archived).take(3).toList();
    if (goals.isEmpty) {
      return FinancialCard(
        child: Text(
          'Nenhuma meta criada ainda.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      children: goals
          .map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FinancialCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleIcon(
                          icon: Icons.flag_outlined,
                          color: Color(g.colorValue),
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            g.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${(g.progress * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Color(g.colorValue),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BudgetProgress(
                      percent: g.progress * 100,
                      color: Color(g.colorValue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Money.format(g.accumulatedCents)} de ${Money.format(g.targetCents)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openTimeline(BuildContext context, FinanceEngine engine) {
    final timeline = engine.timeline(days: 90);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerTheme.color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Timeline financeira',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: timeline.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_available_outlined,
                          title: 'Sem eventos futuros',
                          message:
                              'Registre movimentações ou recorrências para ver sua timeline.',
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: timeline.length,
                          itemBuilder: (_, i) {
                            final item = timeline[i];
                            return _timelineRow(
                              ctx,
                              item.event,
                              item.balanceAfter,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timelineRow(BuildContext context, CashEvent e, int balanceAfter) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleIcon(
                icon: e.isInflow ? Icons.arrow_downward : Icons.arrow_upward,
                color: e.isInflow ? AppColors.positive : AppColors.negativeSoft,
                size: 36,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateHelpers.friendly(e.date),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(e.label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  'Saldo após evento: ${Money.format(balanceAfter)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          MoneyDisplay(
            e.amountCents,
            fontSize: 15,
            colorize: true,
            signed: true,
          ),
        ],
      ),
    );
  }

  void _openNotifications(BuildContext context, AppController c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final list = List.of(c.notifications)
          ..sort((a, b) => b.date.compareTo(a.date));
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerTheme.color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Notificações',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? const EmptyState(
                          icon: Icons.notifications_none,
                          title: 'Nenhuma notificação',
                          message:
                              'Avisos sobre faturas, orçamentos e saldo projetado aparecerão aqui.',
                        )
                      : ListView.builder(
                          controller: sc,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final n = list[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InsightCard(
                                icon: Icons.notifications_none,
                                color: switch (n.severity) {
                                  InsightSeverity.positive =>
                                    AppColors.positive,
                                  InsightSeverity.info => AppColors.info,
                                  InsightSeverity.warning => AppColors.warning,
                                  InsightSeverity.critical =>
                                    AppColors.negative,
                                },
                                title: n.title,
                                message: n.message,
                              ),
                            );
                          },
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
