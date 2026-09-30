import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../budgets/budgets_screen.dart';
import '../goals/goal_form_screen.dart';
import '../shell/app_drawer.dart';

/// Metas (cap. 27/28): progresso, quanto falta, prazo e contribuição mensal.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final goals = c.goals.where((g) => !g.archived).toList();

    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(
        title: const Text('Metas'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BudgetsScreen())),
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Orçamentos',
          ),
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GoalFormScreen())),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: goals.isEmpty
          ? EmptyState(
              icon: Icons.flag_outlined,
              title: 'Nenhuma meta ainda',
              message:
                  'Crie objetivos como viagem, reserva ou compra planejada e acompanhe o progresso.',
              actionLabel: 'Criar meta',
              onAction: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GoalFormScreen())),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                for (final g in goals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _GoalCard(
                      goal: g,
                      monthly: engine.monthlyNeededForGoal(g),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const GoalFormScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova meta'),
                ),
              ],
            ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final int monthly;
  const _GoalCard({required this.goal, required this.monthly});

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    final t = Theme.of(context).textTheme;
    final color = Color(goal.colorValue);
    return FinancialCard(
      onTap: () => _showContribute(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleIcon(icon: Icons.flag, color: color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(goal.name,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                  style: t.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 14),
          BudgetProgress(percent: goal.progress * 100, color: color),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _metric(context, 'Acumulado',
                      Money.format(goal.accumulatedCents))),
              Expanded(
                  child: _metric(context, 'Objetivo',
                      Money.format(goal.targetCents))),
              Expanded(
                  child: _metric(context, 'Faltam',
                      Money.format(goal.remainingCents))),
            ],
          ),
          if (goal.deadline != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.insights, size: 15, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${Money.format(monthly)}/mês para atingir até ${DateHelpers.fullDate.format(goal.deadline!)}.',
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (goal.type == GoalType.emergencyReserve) ...[
            const SizedBox(height: 8),
            Text(
              'Reserva para ${goal.emergencyMonths} meses de custo essencial.',
              style: t.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _showContribute(BuildContext context, AppController c) {
    final amount = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  Text('Contribuir para ${goal.name}',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      final cents = Money.parse(amount.text);
                      if (cents == null || cents <= 0) {
                        showToast(ctx, 'Informe um valor válido.', error: true);
                        return;
                      }
                      await c.contributeToGoal(goal, cents);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Adicionar valor'),
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
