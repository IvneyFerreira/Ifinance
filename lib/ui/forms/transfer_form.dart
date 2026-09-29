import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money_input_formatter.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';
import 'date_field.dart';

/// Transferência entre contas próprias (cap. 17). Não é receita nem despesa;
/// impacto zero no resultado consolidado.
class TransferFormScreen extends StatefulWidget {
  /// Perna de origem (despesa) da transferência a editar, se houver.
  final Transaction? editing;
  const TransferFormScreen({super.key, this.editing});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController(text: 'Transferência');
  String? _fromId;
  String? _toId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    if (c.accounts.isNotEmpty) _fromId = c.accounts.first.id;
    if (c.accounts.length > 1) _toId = c.accounts[1].id;

    final e = widget.editing;
    if (e != null) {
      _amount.text = MoneyInputFormatter.formatCents(e.amountCents);
      _description.text = e.description;
      _fromId = e.accountId ?? _fromId;
      final other = c.transactions.firstWhere(
        (t) => t.transferGroupId == e.transferGroupId && t.id != e.id,
        orElse: () => e,
      );
      _toId = other.accountId ?? _toId;
      _date = e.competenceDate;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Transferência')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FinancialCard(
            color: AppColors.info.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Transferências não são receita nem despesa e não alteram seu resultado financeiro consolidado.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          MoneyField(controller: _amount),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Text('De (conta de origem)',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AccountPicker(
            accounts: c.accounts,
            selectedId: _fromId,
            onSelected: (id) => setState(() => _fromId = id),
          ),
          const SizedBox(height: 18),
          Center(
            child: CircleIcon(
                icon: Icons.arrow_downward, color: AppColors.emerald, size: 44),
          ),
          const SizedBox(height: 18),
          Text('Para (conta de destino)',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AccountPicker(
            accounts: c.accounts,
            selectedId: _toId,
            onSelected: (id) => setState(() => _toId = id),
          ),
          const SizedBox(height: 18),
          DateField(
            value: _date,
            onChanged: (d) => setState(() => _date = d),
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
                : Text(_isEditing ? 'Salvar alterações' : 'Transferir'),
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
    if (_fromId == null || _toId == null) {
      showToast(context, 'Selecione as contas de origem e destino.', error: true);
      return;
    }
    if (_fromId == _toId) {
      showToast(context, 'Escolha contas diferentes.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final c = context.read<AppController>();
      if (_isEditing) {
        // Reconstrói a transferência: remove as pernas antigas e cria novas.
        await c.deleteTransfer(widget.editing!);
      }
      await c.addTransfer(
        fromAccountId: _fromId!,
        toAccountId: _toId!,
        amountCents: cents,
        description: _description.text.trim(),
        date: _date,
      );
      if (mounted) {
        showToast(context,
            _isEditing ? 'Transferência atualizada.' : 'Transferência concluída.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Não foi possível concluir a transferência.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
