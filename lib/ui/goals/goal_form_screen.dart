import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Formulário de meta (cap. 27/28), incluindo Reserva de Emergência.
class GoalFormScreen extends StatefulWidget {
  final Goal? editing;
  const GoalFormScreen({super.key, this.editing});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _accumulated = TextEditingController();
  GoalType _type = GoalType.custom;
  int _emergencyMonths = 6;
  DateTime? _deadline;
  int _color = 0xFF10B981;

  static const _colors = [
    0xFF10B981, 0xFF06B6D4, 0xFF6366F1, 0xFFF59E0B, 0xFFEF4444, 0xFF8B5CF6,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _name.text = e.name;
      _target.text =
          (e.targetCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      _accumulated.text =
          (e.accumulatedCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      _type = e.type;
      _emergencyMonths = e.emergencyMonths;
      _deadline = e.deadline;
      _color = e.colorValue;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _accumulated.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.editing == null ? 'Nova meta' : 'Editar meta')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nome da meta',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tipo',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Objetivo'),
                selected: _type == GoalType.custom,
                onSelected: (_) => setState(() => _type = GoalType.custom),
              ),
              ChoiceChip(
                label: const Text('Reserva de Emergência'),
                selected: _type == GoalType.emergencyReserve,
                onSelected: (_) =>
                    setState(() => _type = GoalType.emergencyReserve),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Valor objetivo (R\$)',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _accumulated,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Já acumulado (R\$)',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
          ),
          if (_type == GoalType.emergencyReserve) ...[
            const SizedBox(height: 14),
            Text('Meses de custo essencial desejados',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [3, 6, 9, 12].map((m) {
                return ChoiceChip(
                  label: Text('$m meses'),
                  selected: _emergencyMonths == m,
                  onSelected: (_) => setState(() => _emergencyMonths = m),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _deadline ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _deadline = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Prazo (opcional)',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(_deadline == null
                  ? 'Sem prazo'
                  : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'),
            ),
          ),
          const SizedBox(height: 18),
          Text('Cor',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: _colors.map((cVal) {
              final selected = _color == cVal;
              return GestureDetector(
                onTap: () => setState(() => _color = cVal),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(cVal),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.emerald : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          FilledButton(onPressed: _save, child: const Text('Salvar meta')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final target = Money.parse(_target.text);
    if (_name.text.trim().isEmpty || target == null || target <= 0) {
      showToast(context, 'Informe nome e valor objetivo.', error: true);
      return;
    }
    final c = context.read<AppController>();
    final e = widget.editing;
    final now = DateTime.now();
    await c.saveGoal(Goal(
      id: e?.id ?? c.repo.newId(),
      userId: c.user!.id,
      name: _name.text.trim(),
      targetCents: target,
      accumulatedCents: Money.parse(_accumulated.text) ?? 0,
      deadline: _deadline,
      type: _type,
      emergencyMonths: _type == GoalType.emergencyReserve ? _emergencyMonths : 0,
      colorValue: _color,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    ));
    if (mounted) {
      showToast(context, 'Meta salva.');
      Navigator.pop(context);
    }
  }
}
