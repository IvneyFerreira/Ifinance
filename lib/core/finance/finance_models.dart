import '../models/enums.dart';

/// Horizontes do seletor da Home (cap. 8).
enum Horizon { today, nextIncome, month }

extension HorizonLabel on Horizon {
  String get label => switch (this) {
        Horizon.today => 'Hoje',
        Horizon.nextIncome => 'Próximo recebimento',
        Horizon.month => 'Mês',
      };
}

/// Evento de caixa: algo que movimenta (ou movimentará) o saldo das contas.
/// amountCents é ASSINADO: positivo = entrada, negativo = saída.
class CashEvent {
  final DateTime date;
  final String label;
  final int amountCents;
  final FinancialEventKind kind;
  final String? sourceId;
  final bool confirmed; // já ocorrido (pago/recebido) vs previsto

  const CashEvent({
    required this.date,
    required this.label,
    required this.amountCents,
    required this.kind,
    this.sourceId,
    this.confirmed = false,
  });

  bool get isInflow => amountCents > 0;
  bool get isOutflow => amountCents < 0;
}

/// Resumo mensal (cap. 9).
class MonthlySummary {
  final DateTime month;
  final int incomeCents; // receitas recebidas no mês
  final int expenseCents; // despesas econômicas do mês
  final int resultCents;
  final int committedIncomeCents; // despesas previstas do mês (comprometido)
  final double committedPercent;

  const MonthlySummary({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.resultCents,
    required this.committedIncomeCents,
    required this.committedPercent,
  });
}

/// Ponto de fluxo para o gráfico Receitas x Despesas (cap. 10).
class FlowPoint {
  final DateTime month;
  final int incomeCents;
  final int expenseCents;
  const FlowPoint({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });
  int get resultCents => incomeCents - expenseCents;
}

/// Ponto de projeção de saldo (cap. 25).
class ProjectionPoint {
  final DateTime date;
  final int balanceCents;
  final bool isActual; // já ocorrido
  const ProjectionPoint(this.date, this.balanceCents, this.isActual);
}

/// Componente do cálculo (para "Ver cálculo" — cap. 39/4).
class CalcComponent {
  final String label;
  final int amountCents;
  final bool isSubtraction;
  const CalcComponent(this.label, this.amountCents,
      {this.isSubtraction = false});
}

/// Explicação de um indicador (cap. 39).
class CalcExplanation {
  final String title;
  final List<CalcComponent> components;
  final int resultCents;
  const CalcExplanation({
    required this.title,
    required this.components,
    required this.resultCents,
  });
}

/// Insights automáticos do Radar Financeiro (cap. 11).
class Insight {
  final InsightSeverity severity;
  final String title;
  final String message;
  const Insight({
    required this.severity,
    required this.title,
    required this.message,
  });
}

/// Dados do Radar Financeiro (cap. 11).
class RadarData {
  final int paymentsCount;
  final int paymentsCents;
  final int receiptsCents;
  final DateTime? nextIncomeDate;
  final int nextIncomeCents;
  final List<Insight> insights;
  const RadarData({
    required this.paymentsCount,
    required this.paymentsCents,
    required this.receiptsCents,
    this.nextIncomeDate,
    this.nextIncomeCents = 0,
    required this.insights,
  });
}

/// Uso de orçamento (cap. 26).
class BudgetUsage {
  final String budgetId;
  final String categoryId;
  final String categoryName;
  final int limitCents;
  final int consumedCents;
  const BudgetUsage({
    required this.budgetId,
    required this.categoryId,
    required this.categoryName,
    required this.limitCents,
    required this.consumedCents,
  });
  int get remainingCents => (limitCents - consumedCents);
  double get percent =>
      limitCents == 0 ? 0 : (consumedCents / limitCents) * 100;
}

/// Estrutura do Patrimônio (cap. 29).
class NetWorth {
  final int assetsCents;
  final int liabilitiesCents;
  final int netCents;
  const NetWorth({
    required this.assetsCents,
    required this.liabilitiesCents,
    required this.netCents,
  });
}

/// Retrato consolidado do dashboard (evita dezenas de queries — cap. 74).
class DashboardData {
  final Horizon horizon;
  final int currentBalanceCents;
  final int committedCents;
  final int safeAvailableCents;
  final int projectedMonthEndCents;
  final MonthlySummary monthSummary;
  final RadarData radar;
  final List<CashEvent> upcomingEvents;
  final int lowestProjectedBalanceCents;
  final DateTime? lowestProjectedBalanceDate;
  const DashboardData({
    required this.horizon,
    required this.currentBalanceCents,
    required this.committedCents,
    required this.safeAvailableCents,
    required this.projectedMonthEndCents,
    required this.monthSummary,
    required this.radar,
    required this.upcomingEvents,
    required this.lowestProjectedBalanceCents,
    this.lowestProjectedBalanceDate,
  });
}
