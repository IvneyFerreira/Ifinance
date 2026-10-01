import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ifinance/core/models/models.dart';
import 'package:ifinance/state/app_controller.dart';
import 'package:ifinance/ui/shell/shell_controller.dart';
import 'package:ifinance/ui/transactions/transactions_screen.dart';

// ---------------------------------------------------------------------------
// Visão mensal de Movimentações: o usuário precisa enxergar, de forma intuitiva,
// como está o mês — quanto entrou/saiu, quanto ainda falta pagar e quanto sobra
// para gastar com segurança.
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
    Intl.defaultLocale = 'pt_BR';
  });

  Widget host(AppController controller) => MaterialApp(
    home: ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: ChangeNotifierProvider<ShellController>.value(
        value: ShellController(),
        child: const TransactionsScreen(),
      ),
    ),
  );

  testWidgets('mostra o resumo do mês, contas a pagar e o valor livre',
      (tester) async {
    final controller = AppController();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, 15);

    controller.accounts = [
      Account(
        id: 'acc1',
        userId: '',
        name: 'Conta',
        balanceCents: 100000,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    controller.transactions = [
      // Conta já paga.
      Transaction(
        id: 'paid',
        userId: '',
        accountId: 'acc1',
        type: TransactionType.expense,
        description: 'Internet',
        amountCents: 12000,
        competenceDate: DateTime(now.year, now.month, 5),
        dueDate: DateTime(now.year, now.month, 5),
        paidAt: DateTime(now.year, now.month, 5),
        expenseStatus: ExpenseStatus.paid,
        createdAt: now,
        updatedAt: now,
      ),
      // Conta ainda em aberto neste mês.
      Transaction(
        id: 'pending',
        userId: '',
        accountId: 'acc1',
        type: TransactionType.expense,
        description: 'Aluguel',
        amountCents: 250000,
        competenceDate: today,
        dueDate: today,
        expenseStatus: ExpenseStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(host(controller));
    await tester.pump();

    // Cartão-resumo do mês.
    expect(find.text('Resumo do mês'), findsOneWidget);
    expect(find.text('Pode gastar com segurança'), findsOneWidget);
    // Aviso amigável de contas em aberto.
    expect(find.textContaining('Falta você pagar'), findsOneWidget);
    // Cabeçalho com o mês (navegação mensal).
    expect(find.textContaining('Voltar para hoje'), findsNothing);
  });
}
