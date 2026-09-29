import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../forms/card_form.dart';
import 'card_detail_screen.dart';

/// Cartões (cap. 18): lista com limite total, utilizado, disponível,
/// fatura atual e próxima fatura.
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CardFormScreen())),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: c.cards.isEmpty
          ? EmptyState(
              icon: Icons.credit_card_off_outlined,
              title: 'Nenhum cartão cadastrado',
              message:
                  'Cadastre seus cartões para acompanhar faturas, limites e compras parceladas.',
              actionLabel: 'Adicionar cartão',
              onAction: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CardFormScreen())),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                for (final card in c.cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CardTile(
                      card: card,
                      used: engine.getCardUsed(card.id),
                      available: engine.getCardAvailable(card.id),
                      currentInvoice: engine.getCurrentInvoiceTotal(card.id),
                      nextInvoice: engine.getNextInvoiceTotal(card.id),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CardFormScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar cartão'),
                ),
              ],
            ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final CreditCard card;
  final int used;
  final int available;
  final int currentInvoice;
  final int nextInvoice;

  const _CardTile({
    required this.card,
    required this.used,
    required this.available,
    required this.currentInvoice,
    required this.nextInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = Color(card.colorValue);
    final usedPercent = card.limitCents == 0
        ? 0.0
        : (used / card.limitCents) * 100;
    return FinancialCard(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CardDetailScreen(card: card)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card, size: 15, color: color),
                    const SizedBox(width: 6),
                    Text(Labels.cardBrand(card.brand),
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Spacer(),
              Text('•••• ${card.lastDigits}',
                  style: t.bodySmall?.copyWith(letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 14),
          Text(card.name,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(card.institution, style: t.bodySmall),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: _metric(context, 'Limite total',
                      Money.formatCompact(card.limitCents))),
              Expanded(
                  child:
                      _metric(context, 'Utilizado', Money.formatCompact(used))),
              Expanded(
                  child: _metric(context, 'Disponível',
                      Money.formatCompact(available))),
            ],
          ),
          const SizedBox(height: 14),
          BudgetProgress(percent: usedPercent, height: 6),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _invoiceBox(
                  context,
                  'Fatura atual',
                  currentInvoice,
                  'Fecha dia ${card.closingDay}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _invoiceBox(
                  context,
                  'Próxima fatura',
                  nextInvoice,
                  'Vence dia ${card.dueDay}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: t.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _invoiceBox(
      BuildContext context, String label, int cents, String subtitle) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.gray100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          MoneyDisplay(cents, fontSize: 16),
          const SizedBox(height: 2),
          Text(subtitle, style: t.bodySmall?.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}
