import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money_input_formatter.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';

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
  final _cardName = TextEditingController(text: 'Cartão principal');
  final _cardLimit = TextEditingController();
  // Passo 7 — objetivo inicial
  final _goalName = TextEditingController(text: 'Reserva de emergência');
  final _goalValue = TextEditingController();

  bool _cardHasLimit = false;
  bool _saving = false;

  // Data de recebimento/vencimento das recorrências (passos 4 e 5).
  _ReceiveMode _incomeMode = _ReceiveMode.fixed;
  int _incomeFixedDay = 5;
  int _incomeBusinessDay = 5;
  _ReceiveMode _expenseMode = _ReceiveMode.fixed;
  int _expenseFixedDay = 5;
  int _expenseBusinessDay = 5;

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
              const CircleIcon(
                icon: Icons.waves,
                color: AppColors.emerald,
                size: 36,
              ),
              const SizedBox(width: 10),
              Text(
                'IFinance',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text('${_step + 1} de ${_stepLabels.length}', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_stepLabels.length, (i) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(
                    right: i == _stepLabels.length - 1 ? 0 : 5,
                  ),
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
        Text(
          'Bem-vindo ao IFinance.',
          style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'Vamos colocar sua vida financeira sob controle.',
          style: t.bodyLarge?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 28),
        FinancialCard(
          gradient: LinearGradient(
            colors: [
              AppColors.emerald.withValues(alpha: 0.16),
              AppColors.emerald.withValues(alpha: 0.04),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.emerald),
              const SizedBox(height: 12),
              Text(
                'Em poucos passos, você terá:',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _bullet('Saldo em contas, comprometido e livre seguro'),
              _bullet('Projeção de como você terminará o mês'),
              _bullet('Radar financeiro dos próximos dias'),
              _bullet('Cartões, faturas e parcelamentos organizados'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FinancialCard(
          color: AppColors.warning.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seus dados ficam só neste celular',
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'O IFinance guarda tudo apenas no armazenamento do seu aparelho. '
                'Nada é enviado para a nuvem nem para nenhum outro local.',
                style: t.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Atenção: se você desinstalar o aplicativo (ou apagar os dados '
                'do app), todas as suas informações serão perdidas '
                'permanentemente e não poderão ser recuperadas. Faça backups '
                'pelo menu Dados quando quiser.',
                style: t.bodySmall?.copyWith(
                  height: 1.4,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          Expanded(
            child: Text(text, style: t.bodyMedium?.copyWith(height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _accountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Cadastre sua primeira conta',
          'Pode ser uma conta corrente, digital ou carteira.',
        ),
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
        _stepTitle('Informe o saldo atual', 'Quanto existe hoje nesta conta.'),
        MoneyField(controller: _balance, label: 'Saldo atual'),
      ],
    );
  }

  Widget _incomeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Cadastre suas receitas principais',
          'Ex.: salário, freelance. Você poderá adicionar mais depois.',
        ),
        TextField(
          controller: _incomeDesc,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        MoneyField(controller: _incomeValue, label: 'Valor'),
        const SizedBox(height: 18),
        _dateSelector(
          title: 'Data de recebimento',
          subtitle:
              'Quando o valor costuma cair. Escolha um dia fixo ou o 5º dia útil.',
          mode: _incomeMode,
          fixedDay: _incomeFixedDay,
          businessDay: _incomeBusinessDay,
          onMode: (m) => setState(() => _incomeMode = m),
          onFixedDay: (d) => setState(() => _incomeFixedDay = d),
          onBusinessDay: (d) => setState(() => _incomeBusinessDay = d),
        ),
      ],
    );
  }

  Widget _expenseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Cadastre suas despesas recorrentes',
          'Ex.: aluguel, internet, escola. O IFinance projetará os próximos meses.',
        ),
        TextField(
          controller: _expenseDesc,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
        ),
        const SizedBox(height: 12),
        MoneyField(controller: _expenseValue, label: 'Valor mensal'),
        const SizedBox(height: 18),
        _dateSelector(
          title: 'Data de vencimento',
          subtitle:
              'Quando o valor costuma vencer. Escolha um dia fixo ou o 5º dia útil.',
          mode: _expenseMode,
          fixedDay: _expenseFixedDay,
          businessDay: _expenseBusinessDay,
          onMode: (m) => setState(() => _expenseMode = m),
          onFixedDay: (d) => setState(() => _expenseFixedDay = d),
          onBusinessDay: (d) => setState(() => _expenseBusinessDay = d),
        ),
      ],
    );
  }

  Widget _cardStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Cadastre seus cartões',
          'Opcional, mas essencial para acompanhar faturas e parcelamentos.',
        ),
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
        if (_cardHasLimit) MoneyField(controller: _cardLimit, label: 'Limite'),
      ],
    );
  }

  Widget _goalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Defina um objetivo inicial',
          'Você verá o progresso e quanto precisa por mês para atingi-lo.',
        ),
        TextField(
          controller: _goalName,
          decoration: const InputDecoration(
            labelText: 'Objetivo',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
        const SizedBox(height: 12),
        MoneyField(controller: _goalValue, label: 'Valor alvo'),
      ],
    );
  }

  Widget _stepTitle(String title, String subtitle) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: t.bodyMedium?.copyWith(height: 1.4)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _dateSelector({
    required String title,
    required String subtitle,
    required _ReceiveMode mode,
    required int fixedDay,
    required int businessDay,
    required ValueChanged<_ReceiveMode> onMode,
    required ValueChanged<int> onFixedDay,
    required ValueChanged<int> onBusinessDay,
  }) {
    final t = Theme.of(context).textTheme;
    final preview = _formatPreview(mode, fixedDay, businessDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: t.bodySmall?.copyWith(height: 1.35)),
        const SizedBox(height: 12),
        SegmentedButton<_ReceiveMode>(
          segments: const [
            ButtonSegment(
              value: _ReceiveMode.fixed,
              icon: Icon(Icons.event_outlined, size: 18),
              label: Text('Dia fixo'),
            ),
            ButtonSegment(
              value: _ReceiveMode.businessDay,
              icon: Icon(Icons.work_outline, size: 18),
              label: Text('5º dia útil'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onMode(s.first),
        ),
        const SizedBox(height: 12),
        if (mode == _ReceiveMode.fixed)
          DropdownButtonFormField<int>(
            initialValue: fixedDay,
            decoration: const InputDecoration(
              labelText: 'Dia do mês',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem<int>(value: d, child: Text('Dia $d')),
            ],
            onChanged: (v) {
              if (v != null) onFixedDay(v);
            },
          )
        else
          DropdownButtonFormField<int>(
            initialValue: businessDay,
            decoration: const InputDecoration(
              labelText: 'Qual dia útil',
              prefixIcon: Icon(Icons.work_outline),
            ),
            items: [
              for (var d = 1; d <= 10; d++)
                DropdownMenuItem<int>(value: d, child: Text('$dº dia útil')),
            ],
            onChanged: (v) {
              if (v != null) onBusinessDay(v);
            },
          ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_available,
                color: AppColors.info,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  preview,
                  style: t.bodySmall?.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Texto de confirmação do próximo recebimento segundo a escolha.
  String _formatPreview(_ReceiveMode mode, int fixedDay, int businessDay) {
    if (mode == _ReceiveMode.fixed) {
      final next = DateHelpers.nextFixedDay(fixedDay);
      return 'Próximo: ${DateHelpers.fullDate.format(next)} '
          '(dia $fixedDay).';
    }
    final next = DateHelpers.nextNthBusinessDay(businessDay);
    if (next == null) {
      return 'Não foi possível calcular o $businessDayº dia útil.';
    }
    return 'Próximo: ${DateHelpers.fullDate.format(next)} '
        '(${DateHelpers.weekdayName(next)}) — $businessDayº dia útil de '
        '${DateHelpers.monthLabel(next)}.';
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _step == _stepLabels.length - 1
                            ? 'Concluir'
                            : 'Continuar',
                      ),
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
      final controller = context.read<AppController>();
      await _persistStep(6);
      await controller.refresh();
      await _completeOnboarding();
      if (mounted) {
        showToast(context, 'Seu IFinance está pronto.');
      }
      // O root troca para o Shell automaticamente.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _completeOnboarding() async {
    final controller = context.read<AppController>();
    // Marca onboarding como concluído via service.
    await controller.completeOnboarding();
  }

  /// Resolve a data de recebimento segundo a escolha do usuário.
  ///
  /// - Dia fixo: usa o dia escolhido (1..31) — a próxima ocorrência é calculada
  ///   para o dia atual/futuro do mês.
  /// - Dia útil: calcula o N-ésimo dia útil real e guarda esse dia do mês,
  ///   começando pela próxima ocorrência (se o dia útil do mês já passou, vai
  ///   para o mês seguinte).
  _ReceiveDate _resolveReceive(
    _ReceiveMode mode,
    int fixedDay,
    int businessDay,
  ) {
    if (mode == _ReceiveMode.fixed) {
      final next = DateHelpers.nextFixedDay(fixedDay);
      return _ReceiveDate(fixedDay.clamp(1, 31), next);
    }
    final next = DateHelpers.nextNthBusinessDay(businessDay) ?? DateTime.now();
    return _ReceiveDate(next.day, next);
  }

  Future<void> _persistStep(int step) async {
    final controller = context.read<AppController>();
    switch (step) {
      case 1:
        final name = _accName.text.trim().isEmpty
            ? 'Minha conta'
            : _accName.text.trim();
        await controller.saveAccount(
          Account(
            id: controller.repo.newId(),
            userId: controller.user!.id,
            name: name,
            type: _accType,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        break;
      case 2:
        final cents = MoneyInput.parse(_balance.text);
        final accs = controller.accounts;
        if (cents != null && accs.isNotEmpty) {
          final first = accs.first;
          await controller.saveAccount(first.copyWith(balanceCents: cents));
        }
        break;
      case 3:
        final cents = MoneyInput.parse(_incomeValue.text);
        final accs = controller.accounts;
        if (cents != null && cents > 0 && accs.isNotEmpty) {
          final cat = _ensureCategory(
            controller,
            _incomeDesc.text,
            isIncome: true,
          );
          final rec = _resolveReceive(
            _incomeMode,
            _incomeFixedDay,
            _incomeBusinessDay,
          );
          await controller.addIncome(
            description: _incomeDesc.text.trim().isEmpty
                ? 'Receita'
                : _incomeDesc.text.trim(),
            amountCents: cents,
            accountId: accs.first.id,
            categoryId: cat,
            date: rec.start,
            received: false,
          );
          await controller.saveRecurring(
            RecurringRule(
              id: controller.repo.newId(),
              userId: controller.user!.id,
              description: _incomeDesc.text.trim().isEmpty
                  ? 'Receita'
                  : _incomeDesc.text.trim(),
              type: TransactionType.income,
              amountCents: cents,
              accountId: accs.first.id,
              categoryId: cat,
              startDate: rec.start,
              preferredDayOfMonth: rec.day,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
        break;
      case 4:
        final cents = MoneyInput.parse(_expenseValue.text);
        final accs = controller.accounts;
        if (cents != null && cents > 0 && accs.isNotEmpty) {
          final cat = _ensureCategory(
            controller,
            _expenseDesc.text,
            isIncome: false,
          );
          final rec = _resolveReceive(
            _expenseMode,
            _expenseFixedDay,
            _expenseBusinessDay,
          );
          await controller.saveRecurring(
            RecurringRule(
              id: controller.repo.newId(),
              userId: controller.user!.id,
              description: _expenseDesc.text.trim().isEmpty
                  ? 'Despesa'
                  : _expenseDesc.text.trim(),
              type: TransactionType.expense,
              amountCents: cents,
              accountId: accs.first.id,
              categoryId: cat,
              startDate: rec.start,
              preferredDayOfMonth: rec.day,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
        break;
      case 5:
        final name = _cardName.text.trim().isEmpty
            ? 'Cartão principal'
            : _cardName.text.trim();
        final limit = MoneyInput.parse(_cardLimit.text) ?? 0;
        await controller.saveCard(
          CreditCard(
            id: controller.repo.newId(),
            userId: controller.user!.id,
            name: name,
            limitCents: limit,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        break;
      case 6:
        final cents = MoneyInput.parse(_goalValue.text);
        if (cents != null && cents > 0) {
          await controller.saveGoal(
            Goal(
              id: controller.repo.newId(),
              userId: controller.user!.id,
              name: _goalName.text.trim().isEmpty
                  ? 'Meu objetivo'
                  : _goalName.text.trim(),
              targetCents: cents,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  String _ensureCategory(
    AppController controller,
    String hint, {
    required bool isIncome,
  }) {
    final lower = hint.toLowerCase();
    final match = controller.categories.where(
      (c) => c.isIncome == isIncome && lower.contains(c.name.toLowerCase()),
    );
    if (match.isNotEmpty) return match.first.id;
    final fallback = controller.categories.where(
      (c) =>
          c.isIncome == isIncome &&
          (isIncome ? c.name == 'Salário' : c.name == 'Outros'),
    );
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

/// Forma de escolha da data de recebimento/vencimento das recorrências.
enum _ReceiveMode { fixed, businessDay }

/// Data resolvida para uma recorrência: [day] = dia do mês a gravar em
/// `preferredDayOfMonth`; [start] = próxima ocorrência (data inicial da regra).
class _ReceiveDate {
  final int day;
  final DateTime start;
  const _ReceiveDate(this.day, this.start);
}
