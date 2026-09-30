import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/money_input_formatter.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';

/// Orçamentos (cap. 26): limites mensais por categoria, consumido, restante,
/// percentual utilizado.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final usage = c.engine.getBudgetUsage(c.budgets);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamentos'),
        actions: [
          IconButton(
            onPressed: () => _showAdd(context, c),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: usage.isEmpty
          ? EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'Nenhum orçamento definido',
              message:
                  'Defina limites mensais por categoria e acompanhe quanto você já utilizou.',
              actionLabel: 'Criar orçamento',
              onAction: () => _showAdd(context, c),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                for (final u in usage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FinancialCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(u.categoryName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                              ),
                              StatusBadge(
                                label: '${u.percent.toStringAsFixed(0)}% usado',
                                color: u.percent >= 100
                                    ? AppColors.negative
                                    : u.percent >= 80
                                        ? AppColors.warning
                                        : AppColors.positive,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          BudgetProgress(percent: u.percent),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Consumido ${Money.format(u.consumedCents)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                'Restante ${Money.format(u.remainingCents)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Limite mensal ${Money.format(u.limitCents)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showAdd(context, c),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo orçamento'),
                ),
              ],
            ),
    );
  }

  void _showAdd(BuildContext context, AppController c) {
    final amount = TextEditingController();
    String? categoryId =
        c.categories.where((x) => !x.isIncome).isNotEmpty
            ? c.categories.firstWhere((x) => !x.isIncome).id
            : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          final expenseCats = c.categories.where((x) => !x.isIncome).toList();
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Novo orçamento',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: expenseCats.map((cat) {
                        return ChoiceChip(
                          label: Text(cat.name),
                          selected: categoryId == cat.id,
                          onSelected: (_) =>
                              setSheet(() => categoryId = cat.id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    MoneyField(controller: amount, label: 'Limite mensal'),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () async {
                        final cents = MoneyInput.parse(amount.text);
                        if (cents == null || cents <= 0 || categoryId == null) {
                          showToast(ctx, 'Preencha categoria e valor.',
                              error: true);
                          return;
                        }
                        await c.saveBudget(Budget(
                          id: c.repo.newId(),
                          userId: c.user!.id,
                          categoryId: categoryId!,
                          limitCents: cents,
                          createdAt: DateTime.now(),
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Salvar orçamento'),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
