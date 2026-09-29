import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';
import 'date_field.dart';

/// Compra no cartão (cap. 21). Permite parcelamento; cria a compra original e
/// uma parcela por fatura. Regra (cap. 20): é despesa econômica — não movimenta
/// o caixa da conta até o pagamento da fatura.
class CardPurchaseFormScreen extends StatefulWidget {
  const CardPurchaseFormScreen({super.key});

  @override
  State<CardPurchaseFormScreen> createState() => _CardPurchaseFormScreenState();
}

class _CardPurchaseFormScreenState extends State<CardPurchaseFormScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _cardId;
  String? _categoryId;
  int _installments = 1;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    if (c.cards.isNotEmpty) _cardId = c.cards.first.id;
    final cats = c.categories.where((x) => !x.isIncome).toList();
    if (cats.isNotEmpty) _categoryId = cats.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  int get _cents => parseMoney(_amount) ?? 0;
  int get _installmentValue =>
      _installments <= 0 ? 0 : (_cents / _installments).round();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Compra no cartão')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (c.cards.isEmpty)
            EmptyState(
              icon: Icons.credit_card_off_outlined,
              title: 'Nenhum cartão cadastrado',
              message:
                  'Cadastre seus cartões para acompanhar faturas, limites e compras parceladas.',
              actionLabel: 'Cadastrar cartão',
              onAction: () => Navigator.pop(context),
            )
          else ...[
            Text('Cartão',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.cards.map((card) {
                final selected = _cardId == card.id;
                return ChoiceChip(
                  avatar: Icon(Icons.credit_card,
                      size: 16,
                      color: selected ? Colors.white : Color(card.colorValue)),
                  label: Text(card.name),
                  selected: selected,
                  selectedColor: Color(card.colorValue),
                  onSelected: (_) => setState(() => _cardId = card.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            MoneyField(controller: _amount, label: 'Valor total (R\$)'),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 18),
            Text('Parcelamento',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 3, 4, 5, 6, 10, 12, 18, 24].map((n) {
                return ChoiceChip(
                  label: Text(n == 1 ? 'À vista' : '${n}x'),
                  selected: _installments == n,
                  onSelected: (_) => setState(() => _installments = n),
                );
              }).toList(),
            ),
            if (_cents > 0) ...[
              const SizedBox(height: 16),
              FinancialCard(
                gradient: LinearGradient(colors: [
                  AppColors.emerald.withValues(alpha: 0.14),
                  AppColors.emerald.withValues(alpha: 0.03),
                ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prévia do parcelamento',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      _installments == 1
                          ? '1x de ${Money.format(_cents)}'
                          : '$_installments x de ${Money.format(_installmentValue)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
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
              label: 'Data da compra',
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
                  : const Text('Registrar compra'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_cardId == null) return;
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
    try {
      await context.read<AppController>().addCardPurchase(
            creditCardId: _cardId!,
            description: _description.text.trim(),
            totalCents: cents,
            installmentsCount: _installments,
            categoryId: _categoryId,
            purchaseDate: _date,
          );
      if (mounted) {
        showToast(context, 'Compra registrada.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Não foi possível registrar a compra.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
