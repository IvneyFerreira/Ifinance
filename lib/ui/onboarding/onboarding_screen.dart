import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Onboarding (cap. 51): guia o usuário em 7 etapas até "Seu IFinance está pronto".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  // Passo 2 — conta
  final _accName = TextEditingController(text: 'Minha conta');
  AccountType _accType = AccountType.checking;
  // Passo 3 — saldo
  final _balance = TextEditingController();
  // Passo 4 — receita
  final _incomeDesc = TextEditingController(text: 'Salário');
  final _incomeValue = TextEditingController();
  // Passo 5 — despesa recorrente
  final _expenseDesc = TextEditingController(text: 'Aluguel');
  final _expenseValue = TextEditingController();
  // Passo 6 — cartão
  final _cardName = TextEditingController(text: 'Cartão principal');
  final _cardLimit = TextEditingController();
  // Passo 7 — objetivo inicial
  final _goalName = TextEditingController(text: 'Reserva de emergência');
  final _goalValue = TextEditingController();

  bool _cardHasLimit = false;
  bool _saving = false;

  @override
  void dispose() {
    _accName.dispose();
    _balance.dispose();
    _incomeDesc.dispose();
    _incomeValue.dispose();
    _expenseDesc.dispose();
    _expenseValue.dispose();
    _cardName.dispose();
    _cardLimit.dispose();
    _goalName.dispose();
    _goalValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _progressHeader(t),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _navBar(),
          ],
        ),
      ),
    );
  }

  Widget _progressHeader(TextTheme t) {
    final labels = _stepLabels;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleIcon(icon: Icons.waves, color: AppColors.emerald, size: 36),
              const SizedBox(width: 10),
              Text('IFinance',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${_step + 1} de ${_stepLabels.length}',
                  style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_stepLabels.length, (i) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == _stepLabels.length - 1 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? AppColors.emerald
                        : Theme.of(context).dividerTheme.color,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(labels[_step], style: t.bodySmall),
        ],
      ),
    );
  }

  static const _stepLabels = [
    'Conta criada',
    'Primeira conta financeira',
    'Saldo atual',
    'Receitas principais',
    'Despesas recorrentes',
    'Cartões',
    'Objetivo inicial',
  ];

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _welcome();
      case 1:
        return _accountStep();
      case 2:
        return _balanceStep();
      case 3:
        return _incomeStep();
      case 4:
        return _expenseStep();
      case 5:
        return _cardStep();
      default:
        return _goalStep();
    }
  }

  Widget _welcome() {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Bem-vindo ao IFinance.',
            style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Vamos colocar sua vida financeira sob controle.',
            style: t.bodyLarge?.copyWith(height: 1.4)),
        const SizedBox(height: 28),
        FinancialCard(
          gradient: LinearGradient(colors: [
            AppColors.emerald.withValues(alpha: 0.16),
            AppColors.emerald.withValues(alpha: 0.04),
          ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.emerald),
              const SizedBox(height: 12),
              Text('Em poucos passos, você terá:',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _bullet('Saldo em contas, comprometido e livre seguro'),
              _bullet('Projeção de como você terminará o mês'),
              _bullet('Radar financeiro dos próximos dias'),
              _bullet('Cartões, faturas e parcelamentos organizados'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.emerald, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: t.bodyMedium?.copyWith(height: 1.35))),
        ],
      ),
    );
  }

  Widget _accountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Cadastre sua primeira conta',
            'Pode ser uma conta corrente, digital ou carteira.'),
        TextField(
          controller: _accName,
          decoration: const InputDecoration(
            labelText: 'Nome da conta',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AccountType.values.map((t) {
            final selected = _accType == t;
            return ChoiceChip(
              label: Text(Labels.accountType(t)),
              selected: selected,
              onSelected: (_) => setState(() => _accType = t),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _balanceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Informe o saldo atual',
            'Quanto existe hoje nesta conta.'),
        TextField(
          controller: _balance,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Saldo atual (R\$)',
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
      ],
    );
  }

  Widget _incomeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Cadastre suas receitas principais',
            'Ex.: salário, freelance. Você poderá adicionar mais depois.'),
        TextField(
          controller: _incomeDesc,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _incomeValue,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Valor (R\$)',
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
      ],
    );
  }

  Widget _expenseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Cadastre suas despesas recorrentes',
            'Ex.: aluguel, internet, escola. O IFinance projetará os próximos meses.'),
        TextField(
          controller: _expenseDesc,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _expenseValue,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Valor mensal (R\$)',
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
      ],
    );
  }

  Widget _cardStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Cadastre seus cartões',
            'Opcional, mas essencial para acompanhar faturas e parcelamentos.'),
        TextField(
          controller: _cardName,
          decoration: const InputDecoration(
            labelText: 'Nome do cartão',
            prefixIcon: Icon(Icons.credit_card_outlined),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Informar limite agora'),
          value: _cardHasLimit,
          onChanged: (v) => setState(() => _cardHasLimit = v),
        ),
        if (_cardHasLimit)
          TextField(
            controller: _cardLimit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Limite (R\$)',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
      ],
    );
  }

  Widget _goalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Defina um objetivo inicial',
            'Você verá o progresso e quanto precisa por mês para atingi-lo.'),
        TextField(
          controller: _goalName,
          decoration: const InputDecoration(
            labelText: 'Objetivo',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goalValue,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Valor alvo (R\$)',
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
      ],
    );
  }

  Widget _stepTitle(String title, String subtitle) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: t.bodyMedium?.copyWith(height: 1.4)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _navBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _step--),
                  child: const Text('Voltar'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving ? null : _next,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_step == _stepLabels.length - 1
                        ? 'Concluir'
                        : 'Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (_step < _stepLabels.length - 1) {
      // Persistência incremental em cada etapa que contém dados.
      await _persistStep(_step);
      if (mounted) setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      await _persistStep(6);
      final controller = context.read<AppController>();
      await controller.refresh();
      final user = controller.user!;
      await _completeOnboarding();
      if (mounted) {
        showToast(context, 'Seu IFinance está pronto.');
      }
      // O root troca para o Shell automaticamente.
      // ignore: unused_local_variable
      final _ = user;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _completeOnboarding() async {
    final controller = context.read<AppController>();
    // Marca onboarding como concluído via service.
    await controller.completeOnboarding();
  }

  Future<void> _persistStep(int step) async {
    final controller = context.read<AppController>();
    switch (step) {
      case 1:
        final name = _accName.text.trim().isEmpty ? 'Minha conta' : _accName.text.trim();
        await controller.saveAccount(Account(
          id: controller.repo.newId(),
          userId: controller.user!.id,
          name: name,
          type: _accType,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        break;
      case 2:
        final cents = Money.parse(_balance.text);
        final accs = controller.accounts;
        if (cents != null && accs.isNotEmpty) {
          final first = accs.first;
          await controller.saveAccount(
              first.copyWith(balanceCents: cents));
        }
        break;
      case 3:
        final cents = Money.parse(_incomeValue.text);
        final accs = controller.accounts;
        if (cents != null && cents > 0 && accs.isNotEmpty) {
          final cat = _ensureCategory(controller, _incomeDesc.text, isIncome: true);
          await controller.addIncome(
            description: _incomeDesc.text.trim().isEmpty
                ? 'Receita'
                : _incomeDesc.text.trim(),
            amountCents: cents,
            accountId: accs.first.id,
            categoryId: cat,
            received: false,
          );
          await controller.saveRecurring(RecurringRule(
            id: controller.repo.newId(),
            userId: controller.user!.id,
            description: _incomeDesc.text.trim().isEmpty
                ? 'Receita'
                : _incomeDesc.text.trim(),
            type: TransactionType.income,
            amountCents: cents,
            accountId: accs.first.id,
            categoryId: cat,
            startDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
        break;
      case 4:
        final cents = Money.parse(_expenseValue.text);
        final accs = controller.accounts;
        if (cents != null && cents > 0 && accs.isNotEmpty) {
          final cat = _ensureCategory(controller, _expenseDesc.text, isIncome: false);
          await controller.saveRecurring(RecurringRule(
            id: controller.repo.newId(),
            userId: controller.user!.id,
            description: _expenseDesc.text.trim().isEmpty
                ? 'Despesa'
                : _expenseDesc.text.trim(),
            type: TransactionType.expense,
            amountCents: cents,
            accountId: accs.first.id,
            categoryId: cat,
            startDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
        break;
      case 5:
        final name = _cardName.text.trim().isEmpty
            ? 'Cartão principal'
            : _cardName.text.trim();
        final limit = Money.parse(_cardLimit.text) ?? 0;
        await controller.saveCard(CreditCard(
          id: controller.repo.newId(),
          userId: controller.user!.id,
          name: name,
          limitCents: limit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        break;
      case 6:
        final cents = Money.parse(_goalValue.text);
        if (cents != null && cents > 0) {
          await controller.saveGoal(Goal(
            id: controller.repo.newId(),
            userId: controller.user!.id,
            name: _goalName.text.trim().isEmpty
                ? 'Meu objetivo'
                : _goalName.text.trim(),
            targetCents: cents,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
        break;
      default:
        break;
    }
  }

  String _ensureCategory(AppController controller, String hint,
      {required bool isIncome}) {
    final lower = hint.toLowerCase();
    final match = controller.categories.where((c) =>
        c.isIncome == isIncome && lower.contains(c.name.toLowerCase()));
    if (match.isNotEmpty) return match.first.id;
    final fallback = controller.categories.where((c) =>
        c.isIncome == isIncome &&
        (isIncome ? c.name == 'Salário' : c.name == 'Outros'));
    if (fallback.isNotEmpty) return fallback.first.id;
    return controller.categories
        .where((c) => c.isIncome == isIncome)
        .map((c) => c.id)
        .firstOrNull ??
        '';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
