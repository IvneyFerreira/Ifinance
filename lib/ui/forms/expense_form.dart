import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';
import 'date_field.dart';

/// Nova despesa (cap. 14): valor, descrição, categoria, data, conta/cartão.
/// "Mais detalhes": subcategoria/tags/observação/recorrência/centro de custo.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    _accountId = c.accounts.isNotEmpty ? c.accounts.first.id : null;
    final expenseCats = c.categories.where((x) => !x.isIncome).toList();
    if (expenseCats.isNotEmpty) _categoryId = expenseCats.first.id;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nova despesa')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
                : const Text('Salvar despesa'),
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
    setState(() => _saving = true);
    final c = context.read<AppController>();
    try {
      if (_cardId != null) {
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
      if (mounted) {
        showToast(context, 'Despesa registrada.');
        Navigator.pop(context);
      }
    } catch (e) {
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
