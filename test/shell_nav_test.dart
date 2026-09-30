import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ifinance/state/app_controller.dart';
import 'package:ifinance/ui/assistant/assistant_screen.dart';
import 'package:ifinance/ui/shell/app_drawer.dart';
import 'package:ifinance/ui/shell/shell_controller.dart';

void main() {
  group('Menus e navegação', () {
    testWidgets('Assessor IA abre a interface de conversa', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AssistantScreen()),
      );
      await tester.pump();

      // Título da conversa e campo de entrada.
      expect(find.text('IFinance Assessor'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      // Sugestões iniciais de perguntas financeiras.
      expect(find.text('Onde estou gastando mais?'), findsOneWidget);
    });

    testWidgets('Menu (gaveta) lista o Assessor IA e os módulos',
        (tester) async {
      final controller = AppController();
      final shell = ShellController();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppController>.value(
            value: controller,
            child: ChangeNotifierProvider<ShellController>.value(
              value: shell,
              child: Scaffold(
                drawer: const AppDrawer(),
                body: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      // Abre a gaveta.
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Assessor IA'), findsOneWidget);
      expect(find.text('Converse com a IA sobre suas finanças'), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Movimentações'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });

    test('ShellController troca a aba selecionada', () {
      final shell = ShellController();
      var notified = 0;
      shell.addListener(() => notified++);

      expect(shell.index, 0);
      shell.select(2);
      expect(shell.index, 2);
      expect(notified, 1);

      // Selecionar a mesma aba não notifica novamente.
      shell.select(2);
      expect(notified, 1);
    });
  });
}
