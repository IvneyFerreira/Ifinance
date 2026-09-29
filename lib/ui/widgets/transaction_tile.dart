import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/widgets/components.dart';

/// TransactionItem (cap. 48): linha de movimentação com ícone, descrição,
/// categoria e valor colorido.
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final CreditCard? card;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = Color(category?.colorValue ?? 0xFF6B7280);
    final icon = CategoryIcons.get(category?.iconName ?? 'category');

    final isTransfer = transaction.isTransfer;
    final isInvoicePayment = transaction.isInvoicePayment;
    final isIncome = transaction.isIncome && !isTransfer;

    final Color amountColor = isTransfer
        ? AppColors.info
        : isIncome
            ? AppColors.positive
            : AppColors.negativeSoft;

    final int amount = isTransfer
        ? transaction.amountCents
        : transaction.amountCents;

    final String prefix = isTransfer
        ? ''
        : isIncome
            ? '+ '
            : '− ';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleIcon(
              icon: isTransfer
                  ? Icons.swap_horiz
                  : isInvoicePayment
                      ? Icons.receipt_long_outlined
                      : icon,
              color: isTransfer ? AppColors.info : color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isEmpty
                        ? (isIncome ? 'Receita' : 'Despesa')
                        : transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    style: t.bodySmall?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$prefix${_format(amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_statusChip() != null) ...[
                  const SizedBox(height: 4),
                  _statusChip()!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    if (transaction.isTransfer) return 'Transferência';
    if (transaction.isInvoicePayment) {
      return 'Pagamento de fatura${card != null ? ' • ${card!.name}' : ''}';
    }
    if (transaction.creditCardId != null) {
      final inst = transaction.description;
      final match = RegExp(r'\((\d+/\d+)\)').firstMatch(inst);
      final base = card?.name ?? 'Cartão';
      if (match != null) return '$base • ${match.group(1)}';
      return '$base • à vista';
    }
    return category?.name ?? (account?.name ?? 'Sem categoria');
  }

  Widget? _statusChip() {
    if (transaction.isTransfer || transaction.isInvoicePayment) return null;
    if (transaction.creditCardId != null) return null;
    if (transaction.isIncome) {
      final s = transaction.incomeStatus;
      if (s == IncomeStatus.received) return null;
      return StatusBadge(label: Labels.incomeStatus(s), color: _incomeColor(s));
    }
    final s = transaction.expenseStatus;
    if (s == ExpenseStatus.paid) return null;
    return StatusBadge(label: Labels.expenseStatus(s), color: _expenseColor(s));
  }

  Color _incomeColor(IncomeStatus s) => switch (s) {
        IncomeStatus.expected => AppColors.warning,
        IncomeStatus.received => AppColors.positive,
        IncomeStatus.overdue => AppColors.negative,
        IncomeStatus.cancelled => AppColors.gray500,
      };

  Color _expenseColor(ExpenseStatus s) => switch (s) {
        ExpenseStatus.pending => AppColors.warning,
        ExpenseStatus.paid => AppColors.positive,
        ExpenseStatus.overdue => AppColors.negative,
        ExpenseStatus.cancelled => AppColors.gray500,
        ExpenseStatus.scheduled => AppColors.info,
      };

  String _format(int cents) {
    final s = (cents / 100).toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'R\$ $intPart,${parts[1]}';
  }
}
