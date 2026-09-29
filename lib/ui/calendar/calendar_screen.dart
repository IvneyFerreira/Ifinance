import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/finance/finance_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Calendário Financeiro (cap. 23): visão mensal com entradas, saídas, faturas
/// e eventos. Ao selecionar um dia, abre os detalhes.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateHelpers.endOfMonth(_month);
    final events = engine.cashEvents(from: start, to: end);

    final byDay = <int, List<CashEvent>>{};
    for (final e in events) {
      if (DateHelpers.isSameMonth(e.date, _month)) {
        byDay.putIfAbsent(e.date.day, () => []).add(e);
      }
    }

    final firstWeekday = start.weekday; // 1=seg
    final daysInMonth = DateHelpers.daysInMonth(_month.year, _month.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário Financeiro'),
      ),
      body: Column(
        children: [
          _monthHeader(context),
          _weekdayRow(context),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _grid(context, firstWeekday, daysInMonth, byDay),
                  const SizedBox(height: 16),
                  if (_selected != null)
                    _dayDetails(context, byDay[_selected!.day] ?? []),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthHeader(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() =>
                _month = DateTime(_month.year, _month.month - 1, 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              DateHelpers.monthYear.format(_month),
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => setState(() =>
                _month = DateTime(_month.year, _month.month + 1, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _weekdayRow(BuildContext context) {
    const days = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _grid(BuildContext context, int firstWeekday, int daysInMonth,
      Map<int, List<CashEvent>> byDay) {
    final cells = <Widget>[];
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final evts = byDay[d] ?? [];
      final inflows = evts.where((e) => e.isInflow).fold<int>(0, (s, e) => s + e.amountCents);
      final outflows = evts.where((e) => e.isOutflow).fold<int>(0, (s, e) => s + e.amountCents.abs());
      final isSelected = _selected?.day == d;
      final isToday = DateHelpers.isSameDay(DateTime(_month.year, _month.month, d), DateTime.now());
      cells.add(GestureDetector(
        onTap: () => setState(() =>
            _selected = DateTime(_month.year, _month.month, d)),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.emerald.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: AppColors.emerald, width: 1.4)
                : null,
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$d',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      )),
              const Spacer(),
              if (inflows > 0)
                Container(
                  height: 3,
                  width: 16,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: AppColors.positive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (outflows > 0)
                Container(
                  height: 3,
                  width: 16,
                  decoration: BoxDecoration(
                    color: AppColors.negativeSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: cells,
    );
  }

  Widget _dayDetails(BuildContext context, List<CashEvent> events) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateHelpers.fullDate.format(_selected!),
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (events.isEmpty)
          FinancialCard(
            child: Text('Nenhum evento financeiro neste dia.',
                style: t.bodyMedium),
          )
        else
          FinancialCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < events.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleIcon(
                          icon: events[i].isInflow
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: events[i].isInflow
                              ? AppColors.positive
                              : AppColors.negativeSoft,
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(events[i].label,
                                style: t.bodyMedium)),
                        MoneyDisplay(events[i].amountCents,
                            fontSize: 14, colorize: true, signed: true),
                      ],
                    ),
                  ),
                  if (i != events.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
