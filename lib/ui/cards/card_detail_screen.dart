import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Fatura do cartão (cap. 19) — mostra todas as compras da fatura.
class CardDetailScreen extends StatefulWidget {
  final CreditCard card;
  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late DateTime _referenceMonth;

  @override
  void initState() {
    super.initState();
    _referenceMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    final total = engine.invoiceTotal(widget.card.id, _referenceMonth);
    final txs = engine.invoiceTransactions(widget.card.id, _referenceMonth);
    final insts = engine.invoiceInstallments(widget.card.id, _referenceMonth);
    final closing = DateTime(_referenceMonth.year, _referenceMonth.month,
        widget.card.closingDay.clamp(1, 28));
    final due = DateTime(_referenceMonth.year, _referenceMonth.month,
        widget.card.dueDay.clamp(1, 28));
    final paid = txs.isEmpty && insts.isEmpty
        ? false
        : c.transactions.any((t) =>
            t.creditCardId == widget.card.id &&
            t.isInvoicePayment &&
            t.invoiceReferenceMonth != null &&
            DateHelpers.isSameMonth(t.invoiceReferenceMonth!, _referenceMonth));

    return Scaffold(
      appBar: AppBar(title: Text(widget.card.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          // Seletor de mês
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _referenceMonth =
                    DateTime(_referenceMonth.year, _referenceMonth.month - 1, 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateHelpers.monthYear.format(_referenceMonth),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _referenceMonth =
                    DateTime(_referenceMonth.year, _referenceMonth.month + 1, 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FinancialCard(
            gradient: LinearGradient(colors: [
              Color(widget.card.colorValue).withValues(alpha: 0.16),
              Color(widget.card.colorValue).withValues(alpha: 0.03),
            ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Fatura ${DateHelpers.monthLabel(_referenceMonth)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    StatusBadge(
                      label: paid ? 'Paga' : (due.isBefore(DateTime.now()) ? 'Vencida' : 'Aberta'),
                      color: paid
                          ? AppColors.positive
                          : due.isBefore(DateTime.now())
                              ? AppColors.negative
                              : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MoneyDisplay(total, fontSize: 34, fontWeight: FontWeight.w800),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _info(context, 'Fecha em',
                            DateHelpers.friendly(closing))),
                    Expanded(
                        child: _info(context, 'Vence',
                            DateHelpers.friendly(due))),
                  ],
                ),
                if (!paid && total > 0) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: c.accounts.isEmpty
                        ? null
                        : () => _payInvoice(context, total),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Pagar fatura'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Compras da fatura'),
          if (txs.isEmpty && insts.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhuma compra nesta fatura',
              message: 'As compras aparecerão aqui conforme forem lançadas.',
            )
          else
            FinancialCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final t in txs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(t.description,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                          MoneyDisplay(t.amountCents, fontSize: 14),
                        ],
                      ),
                    ),
                  for (final i in insts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Parcela ${i.number}/${i.totalCount}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          MoneyDisplay(i.amountCents, fontSize: 14),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
        Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _payInvoice(BuildContext context, int total) async {
    final c = context.read<AppController>();
    String? accountId = c.accounts.isNotEmpty ? c.accounts.first.id : null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
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
                  Text('Pagar fatura',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'O pagamento sairá da conta selecionada. Isso é uma movimentação de caixa — não duplica a despesa das compras.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  MoneyDisplay(total, fontSize: 28),
                  const SizedBox(height: 16),
                  RadioGroup<String>(
                    groupValue: accountId,
                    onChanged: (v) => setSheet(() => accountId = v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: c.accounts
                          .map((a) => RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: a.id,
                                title: Text(a.name),
                                subtitle: Text(Money.format(a.balanceCents)),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: accountId == null
                        ? null
                        : () async {
                            await c.payInvoice(
                              card: widget.card,
                              referenceMonth: _referenceMonth,
                              totalCents: total,
                              accountId: accountId!,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text('Confirmar pagamento'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
