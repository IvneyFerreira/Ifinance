import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Formulário de cartão (cap. 18): nome, instituição, bandeira, final,
/// limite, fechamento, vencimento, cor.
class CardFormScreen extends StatefulWidget {
  final CreditCard? editing;
  const CardFormScreen({super.key, this.editing});

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _name = TextEditingController();
  final _institution = TextEditingController();
  final _lastDigits = TextEditingController();
  final _limit = TextEditingController();
  CardBrand _brand = CardBrand.visa;
  int _closingDay = 28;
  int _dueDay = 5;
  int _color = 0xFF6366F1;

  static const _colors = [
    0xFF6366F1, 0xFF8B5CF6, 0xFF0EA5E9, 0xFF10B981, 0xFFF59E0B,
    0xFFEF4444, 0xFF1E293B, 0xFFEC4899,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _name.text = e.name;
      _institution.text = e.institution;
      _lastDigits.text = e.lastDigits;
      _limit.text = (e.limitCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      _brand = e.brand;
      _closingDay = e.closingDay;
      _dueDay = e.dueDay;
      _color = e.colorValue;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _lastDigits.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? 'Novo cartão' : 'Editar cartão')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nome do cartão',
              prefixIcon: Icon(Icons.credit_card),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _institution,
            decoration: const InputDecoration(
              labelText: 'Instituição',
              prefixIcon: Icon(Icons.account_balance),
            ),
          ),
          const SizedBox(height: 14),
          Text('Bandeira',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CardBrand.values.map((b) {
              return ChoiceChip(
                label: Text(Labels.cardBrand(b)),
                selected: _brand == b,
                onSelected: (_) => setState(() => _brand = b),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lastDigits,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Final do cartão',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Limite (R\$)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _dayField('Fechamento', _closingDay, (v) => setState(() => _closingDay = v))),
              const SizedBox(width: 12),
              Expanded(child: _dayField('Vencimento', _dueDay, (v) => setState(() => _dueDay = v))),
            ],
          ),
          const SizedBox(height: 18),
          Text('Cor personalizada',
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
          FilledButton(
            onPressed: _save,
            child: const Text('Salvar cartão'),
          ),
        ],
      ),
    );
  }

  Widget _dayField(String label, int value, ValueChanged<int> onChanged) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showDialog<int>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(label),
            content: SizedBox(
              width: 300,
              height: 300,
              child: GridView.count(
                crossAxisCount: 7,
                children: List.generate(31, (i) {
                  final day = i + 1;
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, day),
                    child: Center(
                      child: Text('$day',
                          style: TextStyle(
                            fontWeight: day == value
                                ? FontWeight.w800
                                : FontWeight.w400,
                            color: day == value ? AppColors.emerald : null,
                          )),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text('Dia $value'),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showToast(context, 'Informe o nome do cartão.', error: true);
      return;
    }
    final c = context.read<AppController>();
    final e = widget.editing;
    final now = DateTime.now();
    final card = CreditCard(
      id: e?.id ?? c.repo.newId(),
      userId: c.user!.id,
      name: _name.text.trim(),
      institution: _institution.text.trim(),
      brand: _brand,
      lastDigits: _lastDigits.text.trim(),
      limitCents: Money.parse(_limit.text) ?? 0,
      closingDay: _closingDay,
      dueDay: _dueDay,
      colorValue: _color,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    await c.saveCard(card);
    if (mounted) {
      showToast(context, 'Cartão salvo.');
      Navigator.pop(context);
    }
  }
}
