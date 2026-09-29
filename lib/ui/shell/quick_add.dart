import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/money.dart';
import '../../core/utils/money_input_formatter.dart';
import '../../core/widgets/components.dart';
import '../forms/expense_form.dart';
import '../forms/income_form.dart';
import '../forms/transfer_form.dart';
import '../forms/card_purchase_form.dart';

/// Botão central "+" (cap. 5): Despesa, Receita, Transferência, Compra no cartão.
Future<void> showQuickAdd(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [
      (Icons.trending_down, 'Despesa', AppColors.negativeSoft, 'expense'),
      (Icons.trending_up, 'Receita', AppColors.positive, 'income'),
      (Icons.swap_horiz, 'Transferência', AppColors.info, 'transfer'),
      (Icons.credit_card, 'Compra no cartão', const Color(0xFF8B5CF6), 'card'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('O que você quer registrar?',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...options.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FinancialCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    onTap: () {
                      Navigator.pop(context);
                      _open(context, o.$4);
                    },
                    child: Row(
                      children: [
                        CircleIcon(icon: o.$1, color: o.$3),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(o.$2,
                              style: t.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.gray400),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, String kind) {
    switch (kind) {
      case 'expense':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ExpenseFormScreen()));
        break;
      case 'income':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const IncomeFormScreen()));
        break;
      case 'transfer':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TransferFormScreen()));
        break;
      case 'card':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CardPurchaseFormScreen()));
        break;
    }
  }
}

/// Seletor reutilizável de categoria.
class CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final bool isIncome;
  final ValueChanged<String> onSelected;
  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.isIncome,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final list = categories
        .where((c) => c.isIncome == isIncome && !c.archived)
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: list.map((c) {
        final selected = c.id == selectedId;
        final color = Color(c.colorValue);
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => onSelected(c.id),
          avatar: Icon(CategoryIcons.get(c.iconName),
              size: 16, color: selected ? Colors.white : color),
          label: Text(c.name),
          selectedColor: color,
          labelStyle: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        );
      }).toList(),
    );
  }
}

/// Seletor reutilizável de conta.
class AccountPicker extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  const AccountPicker({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: accounts.map((a) {
        final selected = a.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FinancialCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: Border.all(
              color: selected
                  ? AppColors.emerald
                  : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder),
              width: selected ? 1.6 : 1,
            ),
            onTap: () => onSelected(a.id),
            child: Row(
              children: [
                CircleIcon(
                    icon: Icons.account_balance_wallet_outlined,
                    color: Color(a.colorValue),
                    size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(Labels.accountType(a.type),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                MoneyDisplay(a.balanceCents, fontSize: 14, colorize: false),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: AppColors.emerald, size: 20),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Campo monetário com formatação automática (pt-BR).
///
/// Digite apenas números e a pontuação é aplicada sozinha:
///   3000  -> 3.000,00
///   150075 -> 1.500,75
class MoneyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  const MoneyField({
    super.key,
    required this.controller,
    this.label = 'Valor',
    this.autofocus = false,
  });

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  @override
  void initState() {
    super.initState();
    // Se o valor já chegou sem máscara, formata agora.
    _normalize();
    widget.controller.addListener(_guard);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_guard);
    super.dispose();
  }

  void _normalize() {
    final t = widget.controller.text;
    if (t.trim().isEmpty) return;
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final formatted = MoneyInputFormatter.formatFromDigits(
        digits.replaceFirst(RegExp(r'^0+(?=\d)'), ''));
    if (formatted != t) {
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _guard() {
    // Garante re-render do prefixo/valor quando o texto muda externamente.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [MoneyInputFormatter()],
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: 'R\$ ',
        prefixStyle: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.emerald),
        helperText: widget.controller.text.isEmpty
            ? null
            : 'Valor em reais (pontuação automática)',
      ),
    );
  }
}

/// Helper de validação de valor monetário (a partir do texto mascarado).
int? parseMoney(TextEditingController c) => MoneyInput.parse(c.text);
