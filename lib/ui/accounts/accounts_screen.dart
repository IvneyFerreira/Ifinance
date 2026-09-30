import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/money_input_formatter.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';

/// Contas (cap. 16): tipos, saldo atual, entradas e saídas no mês.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    return Scaffold(
      appBar: AppBar(title: const Text('Contas')),
      body: c.accounts.isEmpty
          ? const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nenhuma conta',
              message: 'Cadastre uma conta para começar a organizar.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                FinancialCard(
                  gradient: LinearGradient(colors: [
                    AppColors.emerald.withValues(alpha: 0.14),
                    AppColors.emerald.withValues(alpha: 0.03),
                  ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo em contas',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      MoneyDisplay(engine.getCurrentBalance(),
                          fontSize: 30, fontWeight: FontWeight.w800),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final a in c.accounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _account(context, c, a, engine),
                  ),
              ],
            ),
    );
  }

  Widget _account(BuildContext context, AppController c, Account a,
      dynamic engine) {
    final t = Theme.of(context).textTheme;
    final inflows = c.transactions
        .where((x) =>
            x.accountId == a.id && x.isIncome && !x.isTransfer && x.isPaid)
        .fold<int>(0, (s, x) => s + x.amountCents);
    final outflows = c.transactions
        .where((x) =>
            x.accountId == a.id && x.isExpense && !x.isTransfer && x.isPaid)
        .fold<int>(0, (s, x) => s + x.amountCents);
    return FinancialCard(
      onTap: () => _adjust(context, c, a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleIcon(
                  icon: Icons.account_balance_wallet_outlined,
                  color: Color(a.colorValue),
                  size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(Labels.accountType(a.type), style: t.bodySmall),
                  ],
                ),
              ),
              MoneyDisplay(a.balanceCents, fontSize: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Entradas ${Money.formatCompact(inflows)}',
                    style: t.bodySmall
                        ?.copyWith(color: AppColors.positive)),
              ),
              Text('Saídas ${Money.formatCompact(outflows)}',
                  style: t.bodySmall?.copyWith(color: AppColors.negativeSoft)),
            ],
          ),
        ],
      ),
    );
  }

  void _adjust(BuildContext context, AppController c, Account a) {
    final controller =
        TextEditingController(text: Money.formatPlain(a.balanceCents));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  Text('Ajustar saldo',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'O ajuste gera uma movimentação de conciliação. Seu histórico não é alterado silenciosamente.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  MoneyField(controller: controller, label: 'Novo saldo'),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      final cents = MoneyInput.parse(controller.text);
                      if (cents == null) {
                        showToast(ctx, 'Valor inválido.', error: true);
                        return;
                      }
                      await c.adjustBalance(a, cents);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Salvar ajuste'),
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
