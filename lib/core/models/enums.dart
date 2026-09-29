/// Enums centrais do domínio NeyFlow.
/// Regra (cap. 68): não depender apenas de texto traduzido no banco —
/// usamos valores estáveis em inglês (enum.name) e traduzimos na UI.

/// Tipo de movimentação de caixa.
enum TransactionType { income, expense, adjustment }

/// Status de despesa (cap. 68).
enum ExpenseStatus { pending, paid, overdue, cancelled, scheduled }

/// Status de receita (cap. 68).
enum IncomeStatus { expected, received, overdue, cancelled }

/// Tipos de conta (cap. 16).
enum AccountType {
  checking, // Conta corrente
  digital, // Conta digital
  savings, // Poupança
  cash, // Dinheiro
  wallet, // Carteira
  investment, // Investimento
  other, // Outros
}

/// Frequências de recorrência (cap. 22).
enum RecurrenceFrequency {
  weekly, // Semanal
  biweekly, // Quinzenal
  monthly, // Mensal
  bimonthly, // Bimestral
  quarterly, // Trimestral
  semiannual, // Semestral
  annual, // Anual
  custom, // Personalizada (a cada N dias)
}

/// Bandeiras de cartão.
enum CardBrand { visa, mastercard, elo, amex, hipercard, other }

/// Forma de pagamento.
enum PaymentMethod {
  cash, // Dinheiro
  debit, // Débito
  credit, // Crédito (à vista no cartão)
  pix, // Pix
  boleto, // Boleto
  transfer, // Transferência
  other, // Outros
}

/// Natureza de dívida/passivo (cap. 29/30).
enum LiabilityType { loan, financing, debt, creditCard, other }

/// Tipos de ativo (cap. 29).
enum AssetType { account, investment, vehicle, realEstate, other }

/// Tipo de meta.
enum GoalType { custom, emergencyReserve }

/// Direção do insight do Radar Financeiro (cap. 11).
enum InsightSeverity { positive, info, warning, critical }

/// Categoria do evento financeiro (calendário/timeline).
enum FinancialEventKind {
  income,
  expense,
  cardInvoice,
  installment,
  goal,
  subscription,
  transfer,
}

/// Mapeia enums para rótulos em Português do Brasil.
class Labels {
  Labels._();

  static String accountType(AccountType t) => switch (t) {
        AccountType.checking => 'Conta corrente',
        AccountType.digital => 'Conta digital',
        AccountType.savings => 'Poupança',
        AccountType.cash => 'Dinheiro',
        AccountType.wallet => 'Carteira',
        AccountType.investment => 'Investimento',
        AccountType.other => 'Outros',
      };

  static String frequency(RecurrenceFrequency f) => switch (f) {
        RecurrenceFrequency.weekly => 'Semanal',
        RecurrenceFrequency.biweekly => 'Quinzenal',
        RecurrenceFrequency.monthly => 'Mensal',
        RecurrenceFrequency.bimonthly => 'Bimestral',
        RecurrenceFrequency.quarterly => 'Trimestral',
        RecurrenceFrequency.semiannual => 'Semestral',
        RecurrenceFrequency.annual => 'Anual',
        RecurrenceFrequency.custom => 'Personalizada',
      };

  static String expenseStatus(ExpenseStatus s) => switch (s) {
        ExpenseStatus.pending => 'Pendente',
        ExpenseStatus.paid => 'Paga',
        ExpenseStatus.overdue => 'Atrasada',
        ExpenseStatus.cancelled => 'Cancelada',
        ExpenseStatus.scheduled => 'Agendada',
      };

  static String incomeStatus(IncomeStatus s) => switch (s) {
        IncomeStatus.expected => 'Prevista',
        IncomeStatus.received => 'Recebida',
        IncomeStatus.overdue => 'Atrasada',
        IncomeStatus.cancelled => 'Cancelada',
      };

  static String paymentMethod(PaymentMethod p) => switch (p) {
        PaymentMethod.cash => 'Dinheiro',
        PaymentMethod.debit => 'Débito',
        PaymentMethod.credit => 'Crédito',
        PaymentMethod.pix => 'Pix',
        PaymentMethod.boleto => 'Boleto',
        PaymentMethod.transfer => 'Transferência',
        PaymentMethod.other => 'Outros',
      };

  static String cardBrand(CardBrand b) => switch (b) {
        CardBrand.visa => 'Visa',
        CardBrand.mastercard => 'Mastercard',
        CardBrand.elo => 'Elo',
        CardBrand.amex => 'Amex',
        CardBrand.hipercard => 'Hipercard',
        CardBrand.other => 'Outra',
      };

  static String liabilityType(LiabilityType t) => switch (t) {
        LiabilityType.loan => 'Empréstimo',
        LiabilityType.financing => 'Financiamento',
        LiabilityType.debt => 'Dívida',
        LiabilityType.creditCard => 'Cartão',
        LiabilityType.other => 'Outros',
      };

  static String assetType(AssetType t) => switch (t) {
        AssetType.account => 'Conta',
        AssetType.investment => 'Investimento',
        AssetType.vehicle => 'Veículo',
        AssetType.realEstate => 'Imóvel',
        AssetType.other => 'Outros',
      };
}
