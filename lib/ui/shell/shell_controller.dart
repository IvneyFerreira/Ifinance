import 'package:flutter/foundation.dart';

/// Estado de navegação do shell principal (aba selecionada).
///
/// Fica disponível para toda a subárvore do [AppShell], permitindo que o
/// [AppDrawer] (e outros widgets) troquem a aba atual sem acoplamento.
class ShellController extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void select(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }
}
