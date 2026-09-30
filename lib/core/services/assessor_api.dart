import 'dart:convert';

import 'package:http/http.dart' as http;

import '../finance/finance_engine.dart';
import '../models/models.dart';
import '../utils/date_helpers.dart';
import '../utils/money.dart';
import 'ai_config.dart';
import 'http_client_factory.dart';

/// IFinance Assessor — cliente da IA real.
///
/// A IA roda no servidor (server.py) e recebe um CONTEXTO FINANCEIRO montado
/// pelo FinanceEngine. A chave de API nunca sai do servidor.
///
/// O endereço do servidor é resolvido por [AiConfig]: pode ser definido pelo
/// próprio usuário (Configurações → Assistente IA), embutido no build
/// (--dart-define=ASSESSOR_API_BASE=...) ou usar a mesma origem do app web.
class AssessorApi {
  AssessorApi({http.Client? client, this.baseUrl = ''})
      : _client = client ?? createDefaultClient();

  final http.Client _client;

  /// Base da API (vazio = usa a resolução dinâmica de [AiConfig]).
  final String baseUrl;

  static const _path = '/api/assessor';

  /// Base efetiva: parâmetro explícito > configuração do app/compilação.
  String get _resolveBase =>
      baseUrl.isNotEmpty ? baseUrl.replaceAll(RegExp(r'/+$'), '') : AiConfig.baseUrl;

  String get _endpoint => '$_resolveBase$_path';

  /// `true` quando há um servidor configurado para consultar.
  bool get isConfigured => _resolveBase.isNotEmpty;

  /// Verifica se a IA está habilitada no servidor.
  Future<bool> health() async {
    final base = _resolveBase;
    if (base.isEmpty) return false;
    try {
      final r = await _client
          .get(Uri.parse('$base/api/health'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return false;
      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return d['ai_enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Envia uma pergunta + contexto para a IA real.
  /// Retorna o texto da resposta.
  Future<String> ask({
    required String question,
    required Map<String, dynamic> context,
    List<Map<String, dynamic>> history = const [],
  }) async {
    final res = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            if (AiConfig.token.isNotEmpty)
              'X-IFinance-Token': AiConfig.token,
          },
          body: jsonEncode({
            'question': question,
            'context': context,
            'history': history,
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw AssessorException('IA indisponível (${res.statusCode}).');
    }
    final d = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final answer = (d['answer'] as String?)?.trim();
    if (answer == null || answer.isEmpty) {
      throw AssessorException('A IA não retornou uma resposta.');
    }
    return answer;
  }
}

class AssessorException implements Exception {
  final String message;
  AssessorException(this.message);
  @override
  String toString() => message;
}

/// Monta o contexto financeiro (em valores pt-BR) a partir do FinanceEngine.
/// Foco: despesas e entradas — nada de dados irrelevantes.
class FinancialContext {
  FinancialContext._();

  static Map<String, dynamic> build(
      FinanceEngine engine, List<Budget> budgets) {
    final now = DateTime.now();
    final until = DateHelpers.endOfMonth(now);
    final summary = engine.getMonthlySummary(now);

    final safe = engine.assistantSafeToSpend();
    final top = engine.assistantTopCategories(limit: 8);

    final totalExpense = summary.expenseCents == 0 ? 1 : summary.expenseCents;

    // Entradas do mês (receitas) — das transações do usuário.
    final monthStart = DateHelpers.startOfMonth(now);
    final incomes = engine.transactions
        .where((t) =>
            t.type == TransactionType.income &&
            !DateHelpers.dateOnly(t.competenceDate).isBefore(monthStart) &&
            !DateHelpers.dateOnly(t.competenceDate).isAfter(until))
        .toList()
      ..sort((a, b) => b.competenceDate.compareTo(a.competenceDate));

    // Assinaturas (despesas recorrentes).
    final subsList = engine.subscriptions
        .where((s) => s.active)
        .map((s) => {
              'name': s.name,
              'amount': Money.format(s.amountCents),
              'freq': Labels.frequency(s.frequency),
            })
        .toList();

    // Cartões: faturas (gastos).
    final cards = <Map<String, dynamic>>[];
    for (final c in engine.cards) {
      cards.add({
        'name': c.name,
        'currentInvoice': Money.format(engine.getCurrentInvoiceTotal(c.id)),
        'available': Money.format(engine.getCardAvailable(c.id)),
      });
    }

    // Orçamentos de despesa.
    final budgetsUsage = engine.getBudgetUsage(budgets, now).map((b) => {
          'name': b.categoryName,
          'spent': Money.format(b.consumedCents),
          'limit': Money.format(b.limitCents),
          'percent': Money.formatPercent(b.percent),
        }).toList();

    final next = engine.getNextIncome();

    return {
      'today': DateHelpers.friendly(now),
      'monthLabel': DateHelpers.monthLabel(now),
      'available': Money.format(engine.getCurrentBalance()),
      'safeToSpend': Money.format((safe['free'] as int?) ?? 0),
      'nextIncome': next == null
          ? 'sem previsão'
          : '${Money.format(next.amount)} em ${DateHelpers.friendly(next.date)}',
      'month': {
        'income': Money.format(summary.incomeCents),
        'expense': Money.format(summary.expenseCents),
        'result': Money.format(summary.resultCents),
        'savingsRate': Money.formatPercent(engine.savingsRate()),
        'committed': Money.format(engine.getCommittedAmount(until: until)),
      },
      'topCategories': top
          .map((e) => {
                'name': e.name,
                'amount': Money.format(e.amount),
                'percent': Money.formatPercent(
                    Money.percentOf(e.amount, totalExpense)),
              })
          .toList(),
      'incomes': incomes
          .take(8)
          .map((t) => {
                'name': t.description,
                'amount': Money.format(t.amountCents),
                'date': DateHelpers.friendly(t.competenceDate),
              })
          .toList(),
      'recentExpenses': _recentExpenses(engine, now),
      'subscriptions': {
        'monthly': Money.format(engine.getSubscriptionsMonthlyCost()),
        'annual': Money.format(engine.getSubscriptionsAnnualCost()),
        'list': subsList,
      },
      'cards': cards,
      'budgets': budgetsUsage,
    };
  }

  static List<Map<String, dynamic>> _recentExpenses(
      FinanceEngine engine, DateTime now) {
    final list = engine.transactions
        .where((t) => t.isEconomicExpense)
        .toList()
      ..sort((a, b) => b.competenceDate.compareTo(a.competenceDate));
    return list.take(10).map((t) {
      final cat = engine.categories.where((c) => c.id == t.categoryId);
      return {
        'date': DateHelpers.friendly(t.competenceDate),
        'name': t.description,
        'category': cat.isNotEmpty ? cat.first.name : 'Sem categoria',
        'amount': Money.format(t.amountCents),
      };
    }).toList();
  }
}
