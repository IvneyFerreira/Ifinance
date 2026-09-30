import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/app_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRÍTICO: carrega os dados de locale pt_BR do intl ANTES de usar qualquer
  // DateFormat('...', 'pt_BR'). Sem isto, o DateFormat lança LocaleDataException
  // na primeira renderização e a tela quebra (fica um bloco cinza no release).
  await initializeDateFormatting('pt_BR');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppController()..bootstrap(),
      child: const IFinanceApp(),
    ),
  );
}
