import 'package:flutter/material.dart' hide Simulation;
import 'package:provider/provider.dart';

import '../../core/finance/finance_engine.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';

/// Simulador (cap. 32/33) — "Posso gastar?".
/// Simula o cenário SEM alterar dados reais. Mostra antes/depois, impacto
/// neste mês e nos meses futuros, e o menor saldo futuro.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final _amount = TextEditingController();
  int _installments = 1;
  bool _viaCard = true;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final engine = c.engine;
    return Scaffold(
      appBar: AppBar(title: const Text('Posso gastar?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text('Simule uma decisão antes de tomar',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('O cenário não altera seus dados reais.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          FinancialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoneyField(controller: _amount, label: 'Quanto pretende gastar? (R\$)'),
                const SizedBox(height: 14),
                Text('Forma',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('À vista'),
                      selected: !_viaCard && _installments == 1,
                      onSelected: (_) => setState(() {
                        _viaCard = false;
                        _installments = 1;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Cartão'),
                      selected: _viaCard,
                      onSelected: (_) => setState(() => _viaCard = true),
                    ),
                  ],
                ),
                if (_viaCard) ...[
                  const SizedBox(height: 12),
                  Text('Parcelamento',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 6, 10, 12].map((n) {
                      return ChoiceChip(
                        label: Text('${n}x'),
                        selected: _installments == n,
                        onSelected: (_) =>
                            setState(() => _installments = n),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Text('Data',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Este mês'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _result(context, engine, c),
        ],
      ),
    );
  }

  Widget _result(
      BuildContext context, FinanceEngine engine, AppController c) {
    final cents = Money.parse(_amount.text) ?? 0;
    final t = Theme.of(context).textTheme;

    final freeBefore = engine.assistantSafeToSpend()['free'] as int;
    final until = DateHelpers.endOfMonth(DateHelpers.addMonths(DateTime.now(), 12));
    final lowestBefore = engine.getLowestProjectedBalance(until: until).balance;

    // Simulação: consome do saldo livre no mês corrente; se parcelado, distribui.
    final impactThisMonth = _viaCard && _installments > 1
        ? (cents / _installments).round()
        : cents;
    final freeAfter = freeBefore - impactThisMonth;
    final lowestAfter = lowestBefore - (cents * (12 / _installments).ceil()).clamp(0, cents * 12);

    final ok = freeAfter >= 0 && lowestAfter >= 0;

    return FinancialCard(
      gradient: LinearGradient(colors: [
        (ok ? AppColors.emerald : AppColors.negative).withValues(alpha: 0.14),
        (ok ? AppColors.emerald : AppColors.negative).withValues(alpha: 0.03),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleIcon(
                icon: ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: ok ? AppColors.positive : AppColors.warning,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cents == 0
                      ? 'Informe um valor para simular'
                      : ok
                          ? 'Cabe no seu orçamento'
                          : 'Atenção: aperta seu saldo livre',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row(context, 'Saldo livre hoje', freeBefore),
          _row(context, 'Impacto neste mês', -impactThisMonth),
          const Divider(height: 24),
          _row(context, 'Saldo livre depois', freeAfter, emphasize: true),
          const SizedBox(height: 10),
          _row(context, 'Menor saldo futuro — antes', lowestBefore),
          _row(context, 'Menor saldo futuro — depois', lowestAfter,
              emphasize: true),
          if (_viaCard && _installments > 1) ...[
            const SizedBox(height: 10),
            Text(
              'Parcelado em $_installments x de ${Money.format((cents / _installments).round())}.',
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: c.simulations.isEmpty
                  ? () => _save(context, c, cents)
                  : () => _save(context, c, cents),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Salvar cenário'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int cents,
      {bool emphasize = false}) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: emphasize
                    ? t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                    : t.bodySmall),
          ),
          MoneyDisplay(cents,
              fontSize: emphasize ? 16 : 14,
              colorize: true,
              signed: cents < 0),
        ],
      ),
    );
  }

  Future<void> _save(
      BuildContext context, AppController c, int cents) async {
    if (cents <= 0) {
      showToast(context, 'Informe um valor válido.', error: true);
      return;
    }
    await c.saveSimulation(Simulation(
      id: c.repo.newId(),
      userId: c.user!.id,
      name: 'Compra simulada',
      amountCents: cents,
      installmentsCount: _installments,
      targetDate: _date,
      viaCreditCard: _viaCard,
      createdAt: DateTime.now(),
    ));
    if (context.mounted) {
      showToast(context, 'Cenário salvo.');
    }
  }
}
