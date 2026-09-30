/// IFinance — Importação de extratos (cap. 15/16).
///
/// Interpreta arquivos de extrato bancário em dois formatos comuns:
///  - CSV (separador ';' ou ',') com colunas de data, descrição e valor.
///  - OFX (SGML ou XML) com blocos `STMTTRN`.
///
/// Nenhum dado sai do dispositivo: apenas transformamos texto em lançamentos.
library;

class ImportedRow {
  final DateTime date;
  final String description;
  /// Valor em centavos, ASSINADO (positivo = entrada, negativo = saída).
  final int amountCents;

  const ImportedRow({
    required this.date,
    required this.description,
    required this.amountCents,
  });

  bool get isIncome => amountCents > 0;
}

class StatementImporter {
  StatementImporter._();

  /// Detecta o formato e faz o parsing.
  static List<ImportedRow> parse(String content) {
    final text = content.trim();
    if (text.isEmpty) return const [];
    final upper = text.toUpperCase();
    if (upper.contains('<OFX') ||
        upper.contains('STMTTRN') ||
        upper.contains('<BANKTRANLIST>')) {
      return _parseOfx(text);
    }
    return _parseCsv(text);
  }

  // ---------------------------------------------------------------------------
  // CSV
  // ---------------------------------------------------------------------------

  static List<ImportedRow> _parseCsv(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];

    // Detecta o separador pela primeira linha.
    final sep = _detectSeparator(lines.first);

    // Tenta identificar cabeçalho e colunas.
    int dateCol = -1, descCol = -1, amountCol = -1, debitCol = -1, creditCol = -1;
    var headerFound = false;
    final header = _split(lines.first, sep).map((c) => c.toLowerCase()).toList();
    if (header.any((h) =>
        h.contains('data') ||
        h.contains('date') ||
        h.contains('histórico') ||
        h.contains('historico') ||
        h.contains('descri') ||
        h.contains('valor') ||
        h.contains('amount'))) {
      headerFound = true;
      for (var i = 0; i < header.length; i++) {
        final h = header[i];
        if (dateCol == -1 && (h.contains('data') || h.contains('date'))) {
          dateCol = i;
        } else if (descCol == -1 &&
            (h.contains('histórico') ||
                h.contains('historico') ||
                h.contains('descri') ||
                h.contains('memo') ||
                h.contains('lançamento') ||
                h.contains('lancamento'))) {
          descCol = i;
        } else if (amountCol == -1 &&
            (h.contains('valor') ||
                h.contains('amount') ||
                h.contains('montante'))) {
          amountCol = i;
        } else if (debitCol == -1 && (h.contains('débito') || h.contains('debito'))) {
          debitCol = i;
        } else if (creditCol == -1 &&
            (h.contains('crédito') || h.contains('credito'))) {
          creditCol = i;
        }
      }
    }

    final rows = <ImportedRow>[];
    final start = headerFound ? 1 : 0;
    for (var i = start; i < lines.length; i++) {
      final cols = _split(lines[i], sep);
      if (cols.length < 2) continue;

      final effDateCol = dateCol != -1 ? dateCol : 0;
      final effDescCol = descCol != -1 ? descCol : (cols.length > 1 ? 1 : 0);

      int cents;
      if (amountCol != -1 && amountCol < cols.length) {
        cents = _parseAmount(cols[amountCol]) ?? 0;
      } else if (debitCol != -1 || creditCol != -1) {
        final deb = debitCol != -1 && debitCol < cols.length
            ? _parseAmount(cols[debitCol]) ?? 0
            : 0;
        final cred = creditCol != -1 && creditCol < cols.length
            ? _parseAmount(cols[creditCol]) ?? 0
            : 0;
        cents = cred.abs() - deb.abs();
      } else {
        // Última coluna como valor.
        cents = _parseAmount(cols.last) ?? 0;
      }

      final date = _parseDate(cols[effDateCol]);
      final desc = cols[effDescCol].trim();
      if (date == null || (cents == 0 && desc.isEmpty)) continue;
      rows.add(ImportedRow(
        date: date,
        description: desc.isEmpty ? 'Lançamento importado' : desc,
        amountCents: cents,
      ));
    }
    return rows;
  }

  static String _detectSeparator(String line) {
    final semis = ';'.allMatches(line).length;
    final commas = ','.allMatches(line).length;
    final tabs = '\t'.allMatches(line).length;
    if (tabs > semis && tabs > commas) return '\t';
    return semis >= commas ? ';' : ',';
  }

  static List<String> _split(String line, String sep) {
    final out = <String>[];
    final b = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == sep && !inQuotes) {
        out.add(b.toString());
        b.clear();
      } else {
        b.write(ch);
      }
    }
    out.add(b.toString());
    return out;
  }

  // ---------------------------------------------------------------------------
  // OFX
  // ---------------------------------------------------------------------------

  static List<ImportedRow> _parseOfx(String text) {
    final rows = <ImportedRow>[];
    final blocks = RegExp(r'<STMTTRN>(.*?)</STMTTRN>',
            caseSensitive: false, dotAll: true)
        .allMatches(text);
    for (final m in blocks) {
      final body = m.group(1) ?? '';
      final amount = _ofxTag(body, 'TRNAMT');
      final dateStr = _ofxTag(body, 'DTPOSTED');
      final memo = _ofxTag(body, 'MEMO') ?? _ofxTag(body, 'NAME') ?? '';
      final type = (_ofxTag(body, 'TRNTYPE') ?? '').toUpperCase();

      final cents = _parseAmount(amount ?? '');
      if (cents == null) continue;

      // Alguns bancos trazem TRNAMT positivo e sinal em TRNTYPE.
      var signed = cents;
      if (type == 'DEBIT' && cents > 0) signed = -cents;
      if (type == 'CREDIT' && cents < 0) signed = cents.abs();

      final date = _parseOfxDate(dateStr ?? '');
      if (date == null) continue;

      rows.add(ImportedRow(
        date: date,
        description: memo.trim().isEmpty ? 'Lançamento importado' : memo.trim(),
        amountCents: signed,
      ));
    }
    return rows;
  }

  /// Lê uma tag OFX, tolerando formatos SGML (`TAG valor`) e XML (`TAG valor /TAG`).
  static String? _ofxTag(String body, String tag) {
    final xml = RegExp('<$tag>(.*?)</$tag>',
        caseSensitive: false, dotAll: true).firstMatch(body);
    if (xml != null) return xml.group(1)?.trim();
    final sgml = RegExp('<$tag>([^<\r\n]*)', caseSensitive: false)
        .firstMatch(body);
    return sgml?.group(1)?.trim();
  }

  static DateTime? _parseOfxDate(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return null;
    final y = int.tryParse(digits.substring(0, 4));
    final m = int.tryParse(digits.substring(4, 6));
    final d = int.tryParse(digits.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  // ---------------------------------------------------------------------------
  // Datas e valores (pt-BR)
  // ---------------------------------------------------------------------------

  static DateTime? _parseDate(String raw) {
    final s = raw.trim();
    // ISO: 2026-03-12
    final iso = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (iso != null) {
      return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }
    // BR: 12/03/2026 ou 12/03/26 ou 12-03-2026
    final br = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})').firstMatch(s);
    if (br != null) {
      var year = int.parse(br.group(3)!);
      if (year < 100) year += 2000;
      return DateTime(year, int.parse(br.group(2)!), int.parse(br.group(1)!));
    }
    return null;
  }

  /// Converte texto monetário (pt-BR ou en) em centavos.
  /// Aceita "R$ 1.234,56", "-50,00", "1,234.56", "50,00 D", "(30,00)".
  static int? _parseAmount(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    var negative = false;
    if (s.startsWith('(') && s.endsWith(')')) {
      negative = true;
      s = s.substring(1, s.length - 1);
    }
    final upper = s.toUpperCase();
    if (upper.endsWith('D') || upper.endsWith('DÉBITO')) negative = true;
    if (upper.contains('DÉBITO') || upper.contains('DEBITO')) negative = true;

    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1);
    }
    if (s.isEmpty) return null;

    if (s.contains(',')) {
      // pt-BR: '.' milhar, ',' decimal.
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length > 1 && parts.last.length == 3) {
        // Só milhares: 1.234 -> 1234
        s = s.replaceAll('.', '');
      }
      // senão mantém como decimal (1234.56)
    }

    final value = double.tryParse(s);
    if (value == null) return null;
    final cents = (value.abs() * 100).round();
    return negative ? -cents : cents;
  }
}
