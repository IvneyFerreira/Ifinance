import 'package:flutter/services.dart';

/// IFinance — Máscara monetária (pt-BR), semântica em REAIS.
///
/// O usuário digita o valor em reais e a pontuação é aplicada sozinha:
///   3000    -> 3.000,00
///   1500    -> 1.500,00
///   3000,5  -> 3.000,50
///   12,99   -> 12,99
///
/// Regras:
/// - Enquanto o usuário não digita uma vírgula, os dígitos alimentam a parte
///   inteira (reais) e o campo exibe sempre ",00" ao final.
/// - Ao digitar a vírgula, ativa-se o modo centavos (até 2 dígitos).
class MoneyInputFormatter extends TextInputFormatter {
  String _intD = ''; // dígitos da parte inteira (reais)
  String _centRaw = ''; // 0..2 dígitos de centavos digitados
  bool _centsMode = false;

  static final RegExp _nonDigit = RegExp(r'[^0-9]');

  String get _cents => _centRaw.isEmpty ? '00' : _centRaw.padRight(2, '0');

  static String _group(String d) {
    if (d.isEmpty) return '';
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) b.write('.');
      b.write(d[i]);
    }
    return b.toString();
  }

  /// Formata centavos para exibição pt-BR (sem símbolo). 300000 -> 3.000,00
  static String formatCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final reais = abs ~/ 100;
    final c = abs % 100;
    return '$sign${_group(reais.toString())},${c.toString().padLeft(2, '0')}';
  }

  /// Formata um inteiro de reais. 3000 -> 3.000,00
  static String formatReais(int reais) => formatCents(reais * 100);

  TextEditingValue _render() {
    _intD = _intD.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (_intD.isEmpty && !_centsMode) {
      return const TextEditingValue(text: '');
    }
    final text = '${_group(_intD.isEmpty ? '0' : _intD)},$_cents';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Reprocessa o texto inteiro (usado em colagem/limpeza/inicialização).
  TextEditingValue _fromText(String raw) {
    if (raw.trim().isEmpty) {
      _intD = '';
      _centRaw = '';
      _centsMode = false;
      return const TextEditingValue(text: '');
    }
    if (!raw.contains(',')) {
      _centsMode = false;
      _centRaw = '';
      _intD = raw.replaceAll(_nonDigit, '');
    } else {
      final i = raw.lastIndexOf(',');
      _intD = raw.substring(0, i).replaceAll(_nonDigit, '');
      var c = raw.substring(i + 1).replaceAll(_nonDigit, '');
      if (c.length > 2) c = c.substring(0, 2);
      _centRaw = c;
      _centsMode = true;
    }
    return _render();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldT = oldValue.text;
    final newT = newValue.text;
    if (oldT == newT) return newValue;

    final diff = newT.length - oldT.length;

    // Colagem, limpeza ou qualquer edição múltipla: reprocessa do zero.
    if (diff.abs() != 1) return _fromText(newT);

    if (diff == 1) {
      // Inserção de 1 caractere.
      final idx = _firstDiff(oldT, newT);
      final ch = newT[idx];
      if (ch == ',' || ch == '.') {
        _centsMode = true;
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        if (_centsMode) {
          if (_centRaw.length < 2) _centRaw += ch;
        } else {
          _intD += ch;
        }
      }
    } else {
      // Remoção de 1 caractere.
      final idx = _firstDiff(newT, oldT);
      final ch = oldT[idx];
      if (ch == ',' || ch == '.') {
        _centsMode = false;
        _centRaw = '';
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        if (_centsMode && _centRaw.isNotEmpty) {
          _centRaw = _centRaw.substring(0, _centRaw.length - 1);
          if (_centRaw.isEmpty) _centsMode = false;
        } else {
          _intD =
              _intD.isEmpty ? '' : _intD.substring(0, _intD.length - 1);
        }
      }
    }
    return _render();
  }

  static int _firstDiff(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) return i;
    }
    return n;
  }
}

/// Ajuda de conversão do texto mascarado para centavos.
class MoneyInput {
  MoneyInput._();

  /// "R$ 3.000,00" / "3.000,00" -> 300000 centavos.
  static int? parse(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final cents = int.tryParse(digits);
    if (cents == null || cents <= 0) return null;
    return cents;
  }
}
