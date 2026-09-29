import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';
import 'date_field.dart';

/// Receita (cap. 15): valor, descrição, categoria, data prevista, data
/// recebida, conta, recorrência, status.
class IncomeFormScreen extends StatefulWidget {
  final Transaction? editing;
  const IncomeFormScreen({super.key, this.editing});

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  String? _categoryId;
  String? _accountId;
  DateTime _expectedDate = DateTime.now();
  DateTime? _receivedDate;
  bool _received = false;
  bool _recurring = false;
  RecurrenceFrequency _freq = RecurrenceFrequency.monthly;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    _accountId = c.accounts.isNotEmpty ? c.accounts.first.id : null;
    final cats = c.categories.where((x) => x.isIncome).toList();
    if (cats.isNotEmpty) _categoryId = cats.first.id;
    final e = widget.editing;
    if (e != null) {
      _amount.text = (e.amountCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      _description.text = e.description;
      _notes.text = e.notes;
      _categoryId = e.categoryId ?? _categoryId;
      _accountId = e.accountId ?? _accountId;
      _expectedDate = e.dueDate;
      _receivedDate = e.paidAt;
      _received = e.paidAt != null;
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? 'Nova receita' : 'Editar receita')),
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
          _label('Categoria'),
          const SizedBox(height: 10),
          CategoryPicker(
            categories: c.categories,
            selectedId: _categoryId,
            isIncome: true,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 18),
          DateField(
            value: _expectedDate,
            label: 'Data prevista',
            onChanged: (d) => setState(() => _expectedDate = d),
          ),
          const SizedBox(height: 18),
          _label('Conta de destino'),
          const SizedBox(height: 10),
          AccountPicker(
            accounts: c.accounts,
            selectedId: _accountId,
            onSelected: (id) => setState(() => _accountId = id),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recebida'),
            subtitle: Text(_received
                ? 'Confirmada'
                : 'Prevista'),
            value: _received,
            onChanged: (v) => setState(() {
              _received = v;
              _receivedDate = v ? DateTime.now() : null;
            }),
          ),
          if (_received)
            DateField(
              value: _receivedDate ?? DateTime.now(),
              label: 'Data de recebimento',
              onChanged: (d) => setState(() => _receivedDate = d),
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Receita recorrente'),
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
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Salvar receita'),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Text(s,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700));

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
    if (_accountId == null) {
      showToast(context, 'Cadastre uma conta primeiro.', error: true);
      return;
    }
    setState(() => _saving = true);
    final c = context.read<AppController>();
    try {
      await c.addIncome(
        description: _description.text.trim(),
        amountCents: cents,
        accountId: _accountId!,
        categoryId: _categoryId,
        date: _expectedDate,
        received: _received,
        notes: _notes.text.trim(),
      );
      if (_recurring) {
        await c.saveRecurring(RecurringRule(
          id: c.repo.newId(),
          userId: c.user!.id,
          description: _description.text.trim(),
          type: TransactionType.income,
          amountCents: cents,
          accountId: _accountId,
          categoryId: _categoryId,
          frequency: _freq,
          startDate: _expectedDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      if (mounted) {
        showToast(context, 'Receita registrada.');
        Navigator.pop(context);
      }
    } catch (_) {
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
