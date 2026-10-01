import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:ifinance/state/app_controller.dart';
import 'package:ifinance/ui/forms/income_form.dart';

/// Regressão: ao alternar entre "Dia fixo" (1..31) e "Dia útil" (1..10), o
/// valor do dropdown não pode ficar fora da lista de itens — isso disparava a
/// assert do Flutter (`There should be exactly one item...`) e travava a
/// seleção no app.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
    Intl.defaultLocale = 'pt_BR';
  });

  group('Seletor de dia da recorrência (receita)', () {
    Future<void> pumpIncomeForm(WidgetTester tester) async {
      // Área ampla para todos os campos ficarem visíveis no ListView.
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppController>.value(
            value: controller,
            child: const IncomeFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Dia fixo (dia alto) -> Dia útil não lança exceção',
        (tester) async {
      await pumpIncomeForm(tester);

      // Ativa a recorrência.
      await tester.tap(find.text('Receita recorrente'));
      await tester.pumpAndSettle();

      // Abre o dropdown e escolhe o dia 20 (existe só no modo "Dia fixo").
      await tester.tap(find.text('Dia 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dia 20').last);
      await tester.pumpAndSettle();

      // Alterna para "Dia útil": o dia 20 não existe na lista 1..10.
      await tester.tap(find.text('Dia útil'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Qual dia útil'), findsOneWidget);
    });

    testWidgets('alternar entre os modos mantém a seleção funcional',
        (tester) async {
      await pumpIncomeForm(tester);
      await tester.tap(find.text('Receita recorrente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dia útil'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Qual dia útil'), findsOneWidget);

      await tester.tap(find.text('Dia fixo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Dia do mês'), findsOneWidget);
    });
  });
}
