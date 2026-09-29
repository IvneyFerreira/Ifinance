import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/finance/finance_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../calendar/calendar_screen.dart';
import '../cards/cards_screen.dart';
import '../simulator/simulator_screen.dart';
import '../widgets/charts.dart';

/// Planejamento / Futuro Financeiro (cap. 24/25): horizontes 30d, 3m, 6m, 12m,
/// saldo projetado, ponto de menor/maior saldo e gráfico de projeção.
class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final until = DateHelpers.endOfMonth(DateHelpers.addMonths(DateTime.now(), _months));
    final projected = engine.getProjectedBalance(until);
    final lowest = engine.getLowestProjectedBalance(until: until);
    final series = engine.buildProjectionSeries(until: until);

    return Scaffold(
      appBar: AppBar(title: const Text('Planejamento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text('Futuro Financeiro',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Como estarão suas finanças daqui a alguns meses.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          _horizonSelector(),
          const SizedBox(height: 18),
          FinancialCard(
            gradient: LinearGradient(colors: [
              AppColors.emerald.withValues(alpha: 0.14),
              AppColors.emerald.withValues(alpha: 0.03),
            ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo projetado',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                MoneyDisplay(projected, fontSize: 34, fontWeight: FontWeight.w800),
                Text('até ${DateHelpers.fullDate.format(until)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _mini(context, 'Menor saldo',
                          lowest.balance, lowest.date, AppColors.warning),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Gráfico de projeção'),
          FinancialCard(
            child: Column(
              children: [
                ProjectionChart(points: series),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _legend(context, 'Saldo projetado', AppColors.emerald),
                    const SizedBox(width: 16),
                    _legend(context, 'Saldo negativo', AppColors.negative),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Explorar'),
          Row(
            children: [
              Expanded(
                child: _exploreCard(context, Icons.calendar_month_outlined,
                    'Calendário', CalendarScreen()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _exploreCard(context, Icons.credit_card_outlined,
                    'Cartões', const CardsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _exploreCard(
            context,
            Icons.calculate_outlined,
            'Simulador — Posso gastar?',
            const SimulatorScreen(),
            wide: true,
          ),
        ],
      ),
    );
  }

  Widget _horizonSelector() {
    final opts = [1, 3, 6, 12];
    return Wrap(
      spacing: 8,
      children: opts.map((m) {
        final selected = _months == m;
        return ChoiceChip(
          label: Text(m == 1 ? '30 dias' : '$m meses'),
          selected: selected,
          onSelected: (_) => setState(() => _months = m),
        );
      }).toList(),
    );
  }

  Widget _mini(BuildContext context, String label, int cents, DateTime? date,
      Color color) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
            Text(
              '${Money.format(cents)}${date != null ? ' • ${DateHelpers.dayMonth.format(date)}' : ''}',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _exploreCard(BuildContext context, IconData icon, String label,
      Widget screen, {bool wide = false}) {
    return FinancialCard(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Row(
        children: [
          const CircleIcon(icon: Icons.arrow_forward, color: AppColors.emerald, size: 0),
          Icon(icon, color: AppColors.emerald, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray400),
        ],
      ),
    );
  }
}
