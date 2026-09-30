import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money_input_formatter.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';
import 'date_field.dart';

/// Nova despesa / edição (cap. 14): valor, descrição, categoria, data, conta/cartão.
/// "Mais detalhes": subcategoria/tags/observação/recorrência/centro de custo.
class ExpenseFormScreen extends StatefulWidget {
  final Transaction? editing;
  const ExpenseFormScreen({super.key, this.editing});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  String? _categoryId;
  String? _accountId;
  String? _cardId; // compra no cartão vs conta
  DateTime _date = DateTime.now();
  PaymentMethod _method = PaymentMethod.pix;
  bool _paid = true;
  bool _showMore = false;
  bool _saving = false;
  bool _isInvoicePayment = false;
  bool _recurring = false;
  RecurrenceFrequency _freq = RecurrenceFrequency.monthly;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    _accountId = c.accounts.isNotEmpty ? c.accounts.first.id : null;
    final expenseCats = c.categories.where((x) => !x.isIncome).toList();
    if (expenseCats.isNotEmpty) _categoryId = expenseCats.first.id;

    final e = widget.editing;
    if (e != null) {
      final purchase = e.purchaseId == null
          ? null
          : c.purchases.where((p) => p.id == e.purchaseId).cast<CardPurchase?>().firstOrNull;
      _amount.text = MoneyInputFormatter.formatCents(
          purchase?.totalCents ?? e.amountCents);
      _description.text = purchase?.description ?? e.description;
      _notes.text = e.notes;
      _categoryId = e.categoryId ?? purchase?.categoryId ?? _categoryId;
      _cardId = e.creditCardId;
      _accountId = e.accountId ?? _accountId;
      _date = purchase?.firstReferenceMonth ?? e.competenceDate;
      _method = e.paymentMethod;
      _paid = e.isPaid;
      _isInvoicePayment = e.isInvoicePayment;
    } else {
      _paid = true;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final e = widget.editing;
    final isInvoice = _isInvoicePayment || (e?.isInvoicePayment ?? false);
    return Scaffold(
      appBar: AppBar(
          title: Text(
              e == null ? 'Nova despesa' : (isInvoice ? 'Pagamento de fatura' : 'Editar despesa'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isInvoice) ...[
            FinancialCard(
              color: AppColors.warning.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este é o pagamento de uma fatura (movimentação de caixa). Ele não conta como nova despesa no resultado.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          MoneyField(controller: _amount),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Text('Categoria',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          CategoryPicker(
            categories: c.categories,
            selectedId: _categoryId,
            isIncome: false,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 18),
          DateField(
            value: _date,
            label: 'Data',
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 18),
          Text('Pagar com',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Conta'),
                selected: _cardId == null,
                onSelected: (_) => setState(() => _cardId = null),
              ),
              ...c.cards.map((card) => ChoiceChip(
                    label: Text('Cartão: ${card.name}'),
                    selected: _cardId == card.id,
                    onSelected: (_) => setState(() => _cardId = card.id),
                  )),
            ],
          ),
          const SizedBox(height: 14),
          if (_cardId == null) ...[
            Text('Conta',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            AccountPicker(
              accounts: c.accounts,
              selectedId: _accountId,
              onSelected: (id) => setState(() => _accountId = id),
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => setState(() => _showMore = !_showMore),
            icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
            label: const Text('Mais detalhes'),
          ),
          if (_showMore) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observação',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Text('Forma de pagamento',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PaymentMethod.values.map((m) {
                return ChoiceChip(
                  label: Text(Labels.paymentMethod(m)),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Já paga'),
              value: _paid,
              onChanged: (v) => setState(() => _paid = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Despesa recorrente'),
              subtitle: const Text(
                  'Ex.: aluguel, internet. Aparece nas projeções dos próximos meses.'),
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v),
            ),
            if (_recurring) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RecurrenceFrequency.values.map((f) {
                  return ChoiceChip(
                    label: Text(Labels.frequency(f)),
                    selected: _freq == f,
                    onSelected: (_) => setState(() => _freq = f),
                  );
                }).toList(),
              ),
            ],
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(_isEditing ? 'Salvar alterações' : 'Salvar despesa'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final cents = parseMoney(_amount);
    if (cents == null || cents <= 0) {
      showToast(context, 'Informe um valor válido.', error: true);
      return;
    }
    if (_description.text.trim().isEmpty) {
      showToast(context, 'Informe uma descrição.', error: true);
      return;
    }
    if (_cardId == null && _accountId == null) {
      showToast(context, 'Selecione uma conta.', error: true);
      return;
    }
    setState(() => _saving = true);
    final c = context.read<AppController>();
    final e = widget.editing;
    try {
      if (e != null) {
        if (e.purchaseId != null) {
          // Edição de compra no cartão: reconstrói transações e parcelas.
          final purchase = c.purchases.firstWhere((p) => p.id == e.purchaseId);
          await c.updateCardPurchase(
            purchase: purchase,
            totalCents: cents,
            installmentsCount: purchase.installmentsCount,
            categoryId: _categoryId,
            creditCardId: _cardId,
            description: _description.text.trim(),
            purchaseDate: _date,
          );
        } else {
          await c.updateTransaction(
            e,
            e.copyWith(
              description: _description.text.trim(),
              amountCents: cents,
              categoryId: _categoryId,
              accountId: _cardId == null ? _accountId : null,
              creditCardId: _cardId,
              competenceDate: _date,
              dueDate: _date,
              paymentMethod: _method,
              notes: _notes.text.trim(),
              paidAt: _paid ? (_date) : null,
              clearPaidAt: !_paid,
              expenseStatus: _paid ? ExpenseStatus.paid : ExpenseStatus.pending,
              updatedAt: DateTime.now(),
            ),
          );
        }
      } else if (_cardId != null) {
        await c.addCardPurchase(
          creditCardId: _cardId!,
          description: _description.text.trim(),
          totalCents: cents,
          installmentsCount: 1,
          categoryId: _categoryId,
          purchaseDate: _date,
        );
      } else {
        await c.addExpense(
          description: _description.text.trim(),
          amountCents: cents,
          accountId: _accountId!,
          categoryId: _categoryId,
          date: _date,
          method: _method,
          paid: _paid,
          notes: _notes.text.trim(),
        );
      }
      if (_recurring) {
        final now = DateTime.now();
        await c.saveRecurring(RecurringRule(
          id: c.repo.newId(),
          userId: c.user!.id,
          description: _description.text.trim(),
          type: TransactionType.expense,
          amountCents: cents,
          accountId: _cardId == null ? _accountId : null,
          categoryId: _categoryId,
          creditCardId: _cardId,
          frequency: _freq,
          startDate: _date,
          preferredDayOfMonth: _date.day,
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (mounted) {
        showToast(
            context,
            _isEditing
                ? 'Alterações salvas.'
                : (_recurring
                    ? 'Despesa e recorrência registradas.'
                    : 'Despesa registrada.'));
        Navigator.pop(context);
      }
    } catch (err) {
      if (mounted) {
        showToast(context,
            'Não conseguimos salvar essa movimentação. Seus dados não foram alterados. Tente novamente.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
