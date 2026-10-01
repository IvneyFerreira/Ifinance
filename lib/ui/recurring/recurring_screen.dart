import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/finance/recurrence_materializer.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import 'recurring_form.dart';

/// Recorrências (cap. 22): regras semanais/mensais/anuais, com previsões.
/// Toque em uma regra para editar; use o botão + para criar uma nova.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final rules = c.recurringRules;
    return Scaffold(
      appBar: AppBar(title: const Text('Recorrências')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: rules.isEmpty
          ? const EmptyState(
              icon: Icons.autorenew,
              title: 'Nenhuma recorrência',
              message:
                  'Cadastre gastos e receitas recorrentes (ex.: aluguel). O IFinance projetará os próximos meses.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Text(
                  'Toque em uma recorrência para editar o valor, o dia ou a conta.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final r in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FinancialCard(
                      onTap: () => _openForm(context, rule: r),
                      child: Row(
                        children: [
                          CircleIcon(
                            icon: r.type == TransactionType.income
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: r.type == TransactionType.income
                                ? AppColors.positive
                                : AppColors.negativeSoft,
                            size: 42,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.description,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  _subtitle(r),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (r.creditCardId != null)
                                  Text(
                                    'Cartão',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.info),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MoneyDisplay(
                                r.amountCents,
                                fontSize: 15,
                                colorize: true,
                                signed: r.type == TransactionType.income,
                              ),
                              Switch(
                                value: r.active,
                                onChanged: (_) => c.toggleRecurring(r),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _openForm(BuildContext context, {RecurringRule? rule}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringFormScreen(editing: rule)),
    );
  }

  /// Linha de detalhe: frequência + dia (fixo, "Nº dia útil", ou mesmo dia
  /// da data) + próxima ocorrência (calculada da mesma forma que o Radar).
  String _subtitle(RecurringRule r) {
    String dayPart = '';
    if (r.preferredDayOfMonth != null) {
      dayPart = r.useBusinessDay
          ? ' • ${r.preferredDayOfMonth}º dia útil'
          : ' • dia ${r.preferredDayOfMonth}';
    }
    final next = r.active
        ? RecurrenceMaterializer.nextOccurrence(r) ?? r.startDate
        : r.startDate;
    return '${Labels.frequency(r.frequency)}$dayPart'
        ' • próxima ${DateHelpers.dayMonth.format(next)}';
  }
}

/// Assinaturas (cap. 31): custo mensal e anual estimado.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final subs = c.subscriptions.where((s) => s.active).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Assinaturas')),
      body: subs.isEmpty
          ? const EmptyState(
              icon: Icons.subscriptions_outlined,
              title: 'Nenhuma assinatura',
              message: 'Cadastre streaming, softwares, academia e serviços.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                FinancialCard(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald.withValues(alpha: 0.14),
                      AppColors.emerald.withValues(alpha: 0.03),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _stat(
                          context,
                          'Custo mensal',
                          Money.format(engine.getSubscriptionsMonthlyCost()),
                        ),
                      ),
                      Expanded(
                        child: _stat(
                          context,
                          'Custo anual estimado',
                          Money.format(engine.getSubscriptionsAnnualCost()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final s in subs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FinancialCard(
                      child: Row(
                        children: [
                          const CircleIcon(
                            icon: Icons.autorenew,
                            color: AppColors.info,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Próxima: ${DateHelpers.dayMonth.format(s.nextChargeDate)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          MoneyDisplay(s.amountCents, fontSize: 15),
                        ],
                      ),
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
        Text(
          value,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
