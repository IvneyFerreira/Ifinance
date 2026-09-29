import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../forms/income_form.dart';
import '../widgets/transaction_tile.dart';

/// Movimentações (cap. 13): busca, filtros, período, categorias, contas,
/// cartões, status, tipos. Agrupadas por dia.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _Filter { all, income, expense, card, transfer }

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  String? _categoryId;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final list = _applyFilters(c.transactions);

    // Agrupa por dia
    final grouped = <DateTime, List<Transaction>>{};
    for (final t in list) {
      final key = DateHelpers.dateOnly(t.competenceDate);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimentações'),
        actions: [
          IconButton(
            onPressed: _showFilterSheet,
            icon: Badge(
              isLabelVisible: _activeFilters,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar no IFinance',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          _filterChips(),
          const SizedBox(height: 6),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nenhuma movimentação',
                    message:
                        'Registre sua primeira despesa ou receita usando o botão +.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: days.length,
                    itemBuilder: (_, i) {
                      final day = days[i];
                      final items = grouped[day]!
                        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                      final dayTotal = items.fold<int>(
                        0,
                        (sum, t) => sum + (t.isTransfer ? 0 : t.economicSignedCents),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 18, bottom: 8),
                            child: Row(
                              children: [
                                Text(_dayHeader(day),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                const Spacer(),
                                if (!items.every((t) => t.isTransfer))
                                  MoneyDisplay(dayTotal,
                                      fontSize: 12,
                                      colorize: true,
                                      signed: true),
                              ],
                            ),
                          ),
                          FinancialCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            child: Column(
                              children: [
                                for (var j = 0; j < items.length; j++) ...[
                                  TransactionTile(
                                    transaction: items[j],
                                    category: c.categoryById(items[j].categoryId),
                                    account: c.accountById(items[j].accountId),
                                    card: c.cardById(items[j].creditCardId),
                                    onTap: () => _showDetail(items[j]),
                                  ),
                                  if (j != items.length - 1)
                                    const Divider(height: 1),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool get _activeFilters =>
      _filter != _Filter.all || _categoryId != null || _range != null;

  List<Transaction> _applyFilters(List<Transaction> all) {
    return all.where((t) {
      if (t.deleted) return false;
      final q = _search.text.trim().toLowerCase();
      if (q.isNotEmpty &&
          !t.description.toLowerCase().contains(q)) {
        return false;
      }
      switch (_filter) {
        case _Filter.income:
          if (!t.isIncome || t.isTransfer) return false;
          break;
        case _Filter.expense:
          if (!t.isExpense || t.isTransfer) return false;
          break;
        case _Filter.card:
          if (t.creditCardId == null || t.isInvoicePayment) return false;
          break;
        case _Filter.transfer:
          if (!t.isTransfer) return false;
          break;
        case _Filter.all:
          break;
      }
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_range != null) {
        final d = DateHelpers.dateOnly(t.competenceDate);
        if (d.isBefore(DateHelpers.dateOnly(_range!.start)) ||
            d.isAfter(DateHelpers.dateOnly(_range!.end))) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.competenceDate.compareTo(a.competenceDate));
  }

  String _dayHeader(DateTime d) {
    final f = DateHelpers.friendly(d);
    if (f == 'Hoje' || f == 'Amanhã' || f == 'Ontem') return f;
    return DateHelpers.fullDate.format(d);
  }

  Widget _filterChips() {
    final items = [
      (_Filter.all, 'Tudo'),
      (_Filter.income, 'Receitas'),
      (_Filter.expense, 'Despesas'),
      (_Filter.card, 'Cartão'),
      (_Filter.transfer, 'Transferências'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: items.map((it) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(it.$2),
              selected: _filter == it.$1,
              onSelected: (_) => setState(() => _filter = it.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = context.read<AppController>();
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filtros',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Text('Categoria',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: _categoryId == null,
                        onSelected: (_) {
                          setState(() => _categoryId = null);
                          setSheet(() {});
                        },
                      ),
                      ...c.categories.where((x) => !x.archived).map((cat) {
                        return ChoiceChip(
                          label: Text(cat.name),
                          selected: _categoryId == cat.id,
                          onSelected: (_) {
                            setState(() => _categoryId = cat.id);
                            setSheet(() {});
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Período',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDateRange: _range,
                            );
                            if (picked != null) {
                              setState(() => _range = picked);
                              setSheet(() {});
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(_range == null
                              ? 'Selecionar'
                              : '${DateHelpers.dayMonth.format(_range!.start)} - ${DateHelpers.dayMonth.format(_range!.end)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _categoryId = null;
                              _range = null;
                              _filter = _Filter.all;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Limpar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetail(Transaction t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = context.read<AppController>();
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cat = c.categoryById(t.categoryId);
        final acc = c.accountById(t.accountId);
        final card = c.cardById(t.creditCardId);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
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
                      color: Theme.of(ctx).dividerTheme.color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(t.description,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                MoneyDisplay(t.economicSignedCents,
                    fontSize: 30,
                    colorize: true,
                    signed: !t.isExpense),
                const SizedBox(height: 16),
                _detailRow(ctx, 'Tipo', _typeLabel(t)),
                if (cat != null)
                  _detailRow(ctx, 'Categoria', cat.name),
                if (acc != null) _detailRow(ctx, 'Conta', acc.name),
                if (card != null) _detailRow(ctx, 'Cartão', card.name),
                _detailRow(ctx, 'Data', DateHelpers.fullDate.format(t.competenceDate)),
                _detailRow(ctx, 'Status', _statusLabel(t)),
                if (t.notes.isNotEmpty) _detailRow(ctx, 'Observação', t.notes),
                const SizedBox(height: 18),
                if (!t.isTransfer)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IncomeFormScreen(editing: t),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await c.markTransactionPaid(t, paid: !t.isPaid);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(t.isPaid ? 'Marcar pendente' : 'Confirmar'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        ctx,
                        title: 'Excluir movimentação',
                        message:
                            'Tem certeza que deseja excluir "${t.description}"? Esta ação será registrada.',
                        confirmLabel: 'Excluir',
                        destructive: true,
                      );
                      if (ok) {
                        await c.deleteTransaction(t);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.negative),
                    label: const Text('Excluir',
                        style: TextStyle(color: AppColors.negative)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: Theme.of(ctx).textTheme.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: Theme.of(ctx).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _typeLabel(Transaction t) {
    if (t.isTransfer) return 'Transferência';
    if (t.creditCardId != null && !t.isInvoicePayment) return 'Compra no cartão';
    if (t.isInvoicePayment) return 'Pagamento de fatura';
    if (t.isIncome) return 'Receita';
    if (t.isAdjustment) return 'Ajuste';
    return 'Despesa';
  }

  String _statusLabel(Transaction t) {
    if (t.isIncome) return Labels.incomeStatus(t.incomeStatus);
    if (t.creditCardId != null && !t.isInvoicePayment) return 'Cartão';
    return Labels.expenseStatus(t.expenseStatus);
  }
}
