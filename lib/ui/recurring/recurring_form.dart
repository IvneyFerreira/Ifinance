import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money_input_formatter.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../forms/date_field.dart';
import '../shell/quick_add.dart';

/// Cadastro e edição de uma regra de recorrência (cap. 22).
///
/// Suporta despesas e receitas recorrentes (ex.: aluguel todo dia 5,
/// salário todo dia 30). As ocorrências são materializadas sob demanda em
/// projeções, calendário e radar — não geramos anos de lançamentos.
class RecurringFormScreen extends StatefulWidget {
  final RecurringRule? editing;
  const RecurringFormScreen({super.key, this.editing});

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _accountId;
  String? _cardId; // despesa no cartão (opcional)
  RecurrenceFrequency _freq = RecurrenceFrequency.monthly;
  DateTime _startDate = DateTime.now();
  int? _preferredDay; // dia do mês preferencial (mensal+)
  bool _useBusinessDay = false; // dia = N-ésimo dia útil (ex.: 5º dia útil)
  bool _active = true;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    _accountId = c.accounts.isNotEmpty ? c.accounts.first.id : null;

    final e = widget.editing;
    if (e != null) {
      _amount.text = MoneyInputFormatter.formatCents(e.amountCents);
      _description.text = e.description;
      _type = e.type;
      _categoryId = e.categoryId;
      _accountId = e.accountId ?? _accountId;
      _cardId = e.creditCardId;
      _freq = e.frequency;
      _startDate = e.startDate;
      _preferredDay = e.preferredDayOfMonth;
      _useBusinessDay = e.useBusinessDay;
      _active = e.active;
    } else {
      final cats = c.categories
          .where((x) => x.isIncome == (_type == TransactionType.income))
          .toList();
      if (cats.isNotEmpty) _categoryId = cats.first.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isIncome => _type == TransactionType.income;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar recorrência' : 'Nova recorrência'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MoneyField(controller: _amount),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descrição (ex.: Aluguel)',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 20),
          _label('Tipo'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Despesa'),
                selected: _type == TransactionType.expense,
                onSelected: (_) => setState(() {
                  _type = TransactionType.expense;
                  _categoryId = null;
                }),
              ),
              ChoiceChip(
                label: const Text('Receita'),
                selected: _type == TransactionType.income,
                onSelected: (_) => setState(() {
                  _type = TransactionType.income;
                  _categoryId = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _label('Categoria'),
          const SizedBox(height: 10),
          CategoryPicker(
            categories: c.categories,
            selectedId: _categoryId,
            isIncome: _isIncome,
            onSelected: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 18),
          _label('Pagamento'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Conta'),
                selected: _cardId == null,
                onSelected: (_) => setState(() => _cardId = null),
              ),
              if (!_isIncome)
                ...c.cards.map(
                  (card) => ChoiceChip(
                    label: Text('Cartão: ${card.name}'),
                    selected: _cardId == card.id,
                    onSelected: (_) => setState(() => _cardId = card.id),
                  ),
                ),
            ],
          ),
          if (_cardId == null) ...[
            const SizedBox(height: 14),
            _label('Conta'),
            const SizedBox(height: 10),
            AccountPicker(
              accounts: c.accounts,
              selectedId: _accountId,
              onSelected: (id) => setState(() => _accountId = id),
            ),
          ],
          const SizedBox(height: 18),
          DateField(
            value: _startDate,
            label: 'Início (1ª ocorrência)',
            onChanged: (d) => setState(() => _startDate = d),
          ),
          const SizedBox(height: 18),
          _label('Frequência'),
          const SizedBox(height: 10),
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
          if (_freq != RecurrenceFrequency.weekly &&
              _freq != RecurrenceFrequency.biweekly &&
              _freq != RecurrenceFrequency.custom) ...[
            const SizedBox(height: 18),
            _label('Data de vencimento'),
            const SizedBox(height: 6),
            Text(
              'Como o dia se repete todo mês. Salários costumam usar o '
              '5º dia útil; aluguéis, um dia fixo.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 10),
            SegmentedButton<_DayMode>(
              segments: const [
                ButtonSegment(
                  value: _DayMode.fixed,
                  icon: Icon(Icons.event_outlined, size: 18),
                  label: Text('Dia fixo'),
                ),
                ButtonSegment(
                  value: _DayMode.businessDay,
                  icon: Icon(Icons.work_outline, size: 18),
                  label: Text('Dia útil'),
                ),
              ],
              selected: {
                _useBusinessDay ? _DayMode.businessDay : _DayMode.fixed,
              },
              onSelectionChanged: (s) => setState(() {
                final toBusiness = s.first == _DayMode.businessDay;
                _useBusinessDay = toBusiness;
                // Mantém o dia dentro do intervalo do modo (1..10 útil / 1..31).
                _preferredDay = (_preferredDay ?? _startDate.day)
                    .clamp(1, _dayMax(toBusiness));
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              // Reconstrói ao trocar o modo: evita valor fora da lista.
              key: ValueKey('recurring-day-$_useBusinessDay'),
              initialValue:
                  (_preferredDay ?? _startDate.day).clamp(1, _dayMaxFor),
              decoration: InputDecoration(
                labelText: _useBusinessDay ? 'Qual dia útil' : 'Dia do mês',
                prefixIcon: Icon(
                  _useBusinessDay
                      ? Icons.work_outline
                      : Icons.calendar_today_outlined,
                ),
              ),
              items: [
                for (var d = 1; d <= _dayMaxFor; d++)
                  DropdownMenuItem<int>(
                    value: d,
                    child: Text(_useBusinessDay ? '$dº dia útil' : 'Dia $d'),
                  ),
              ],
              onChanged: (v) => setState(() => _preferredDay = v),
            ),
            if (!_useBusinessDay) ...[
              const SizedBox(height: 8),
              Text(
                'Se o dia cair em fim de semana, o lançamento vai para o '
                'primeiro dia útil seguinte.',
                style: t.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            _dayPreview(t),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativa'),
            subtitle: Text(
              _active ? 'A regra gera previsões' : 'As previsões ficam ocultas',
            ),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Salvar alterações' : 'Criar recorrência'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.negative,
                ),
                label: const Text(
                  'Excluir recorrência',
                  style: TextStyle(color: AppColors.negative),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String s) => Text(
    s,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );

  bool get _showsDaySelector =>
      _freq != RecurrenceFrequency.weekly &&
      _freq != RecurrenceFrequency.biweekly &&
      _freq != RecurrenceFrequency.custom;

  /// Máximo de opções de dia conforme o modo (10 dias úteis / 31 dias fixos).
  int _dayMax(bool businessDay) => businessDay ? 10 : 31;
  int get _dayMaxFor => _dayMax(_useBusinessDay);

  /// Data da próxima ocorrência (1ª) segundo o modo escolhido.
  DateTime _resolvedStart() {
    if (!_showsDaySelector) return _startDate;
    final day = _preferredDay ?? _startDate.day;
    if (_useBusinessDay) {
      return DateHelpers.nextNthBusinessDay(day, from: _startDate) ??
          _startDate;
    }
    return DateHelpers.nextBusinessDayOnOrAfter(
      DateHelpers.nextFixedDay(day, from: _startDate),
    );
  }

  Widget _dayPreview(TextTheme t) {
    final next = _resolvedStart();
    final label = _useBusinessDay
        ? '${DateHelpers.weekdayName(next)}, ${DateHelpers.fullDate.format(next)} '
              '(${_preferredDay ?? _startDate.day}º dia útil)'
        : '${DateHelpers.weekdayName(next)}, ${DateHelpers.fullDate.format(next)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Próxima: $label',
              style: t.bodySmall?.copyWith(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    final now = DateTime.now();
    final e = widget.editing;
    final resolvedStart = _resolvedStart();
    final rule = RecurringRule(
      id: e?.id ?? c.repo.newId(),
      userId: e?.userId ?? c.user!.id,
      description: _description.text.trim(),
      type: _type,
      amountCents: cents,
      accountId: _cardId == null ? _accountId : null,
      categoryId: _categoryId,
      creditCardId: _cardId,
      frequency: _freq,
      customIntervalDays: e?.customIntervalDays ?? 30,
      startDate: resolvedStart,
      endDate: e?.endDate,
      totalOccurrences: e?.totalOccurrences,
      preferredDayOfMonth: _showsDaySelector
          ? (_preferredDay ?? _startDate.day)
          : _preferredDay,
      useBusinessDay: _showsDaySelector && _useBusinessDay,
      active: _active,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    await c.saveRecurring(rule);
    if (!mounted) return;
    showToast(
      context,
      _isEditing ? 'Recorrência atualizada.' : 'Recorrência criada.',
    );
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final e = widget.editing;
    if (e == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Excluir recorrência',
      message:
          'Tem certeza que deseja excluir "${e.description}"? '
          'As previsões dela deixarão de aparecer.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    final c = context.read<AppController>();
    await c.deleteRecurring(e);
    if (!mounted) return;
    showToast(context, 'Recorrência excluída.');
    Navigator.pop(context);
  }
}

/// Forma de recorrência mensal: dia fixo do mês ou N-ésimo dia útil.
enum _DayMode { fixed, businessDay }
