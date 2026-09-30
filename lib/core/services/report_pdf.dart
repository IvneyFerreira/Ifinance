import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../finance/finance_engine.dart';
import '../models/models.dart';
import '../utils/date_helpers.dart';
import '../utils/money.dart';

/// Gera relatórios financeiros em PDF (cap. 35): resumo do período,
/// fluxo mensal de entradas x despesas e despesas por categoria.
///
/// Os valores são lidos do [FinanceEngine], garantindo que os mesmos
/// critérios do app (despesa econômica, cartão, transferências) sejam
/// respeitados — nada é recalculado de forma divergente.
class ReportPdf {
  const ReportPdf._();

  static const _monthAbbr = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  static String _monthLabel(DateTime d) =>
      '${_monthAbbr[d.month - 1]}/${d.year.toString().substring(2)}';

  static String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Constrói o PDF e devolve os bytes prontos para compartilhar/imprimir.
  static Future<Uint8List> build({
    required FinanceEngine engine,
    required List<Transaction> transactions,
    required List<Category> categories,
    required String userName,
    required int months,
  }) async {
    final now = DateTime.now();
    final points = engine.getFlow(months: months, end: now);

    final start =
        DateHelpers.startOfMonth(DateHelpers.addMonths(now, -(months - 1)));
    final end = DateHelpers.endOfMonth(now);

    int income = 0, expense = 0;
    for (final p in points) {
      income += p.incomeCents;
      expense += p.expenseCents;
    }
    final result = income - expense;
    final savings = income == 0 ? 0.0 : (result / income) * 100;

    // Despesas por categoria no período.
    final catName = <String, String>{
      for (final c in categories) c.id: c.name,
    };
    final byCat = <String, int>{};
    for (final tx in transactions) {
      if (!tx.isEconomicExpense) continue;
      final d = DateHelpers.dateOnly(tx.competenceDate);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      final key = tx.categoryId ?? 'none';
      byCat[key] = (byCat[key] ?? 0) + tx.amountCents;
    }
    final catList = byCat.entries
        .map((e) => (name: catName[e.key] ?? 'Sem categoria', amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final catTotal = catList.fold<int>(0, (s, e) => s + e.amount);

    final monthSummary = engine.getMonthlySummary(now);
    final balance = engine.getCurrentBalance();

    final doc = pw.Document(
      title: 'IFinance — Relatório financeiro',
      author: 'IFinance',
    );

    const emerald = PdfColor.fromInt(0xFF10B981);
    const ink = PdfColor.fromInt(0xFF111827);
    const gray = PdfColor.fromInt(0xFF6B7280);
    const positive = PdfColor.fromInt(0xFF16A34A);
    const negative = PdfColor.fromInt(0xFFDC2626);

    pw.Widget kv(String label, String value, {PdfColor? color}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(color: gray, fontSize: 10)),
              pw.Text(value,
                  style: pw.TextStyle(
                      color: color ?? ink,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('IFinance — gerado em ${_dateLabel(now)}',
                  style: const pw.TextStyle(color: gray, fontSize: 8)),
              pw.Text('Página ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: const pw.TextStyle(color: gray, fontSize: 8)),
            ],
          ),
        ),
        build: (ctx) => [
          // Cabeçalho
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('IFinance',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: emerald)),
                  pw.Text('Relatório financeiro',
                      style: const pw.TextStyle(color: ink, fontSize: 12)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Período: ${_monthLabel(start)} a ${_monthLabel(end)}'
                    '  •  $months ${months == 1 ? 'mês' : 'meses'}',
                    style: const pw.TextStyle(color: gray, fontSize: 9),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(userName.isEmpty ? 'Usuário' : userName,
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Emitido em ${_dateLabel(now)}',
                      style: const pw.TextStyle(color: gray, fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColor.fromInt(0xFFE5E7EB)),

          // Resumo do período
          pw.SizedBox(height: 8),
          pw.Text('Resumo do período',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF9FAFB),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                kv('Entradas', Money.format(income), color: positive),
                kv('Despesas', Money.format(expense), color: negative),
                pw.Divider(color: PdfColor.fromInt(0xFFE5E7EB), height: 10),
                kv('Resultado', Money.format(result),
                    color: result >= 0 ? positive : negative),
                kv('Taxa de poupança', Money.formatPercent(savings)),
                kv('Saldo atual em contas', Money.format(balance)),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // Fluxo mensal
          pw.Text('Entradas x Despesas por mês',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Mês', 'Entradas', 'Despesas', 'Resultado'],
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: emerald),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
            data: [
              for (final p in points)
                [
                  _monthLabel(p.month),
                  Money.format(p.incomeCents),
                  Money.format(p.expenseCents),
                  Money.format(p.incomeCents - p.expenseCents),
                ],
              [
                'Total',
                Money.format(income),
                Money.format(expense),
                Money.format(result),
              ],
            ],
          ),

          pw.SizedBox(height: 16),

          // Despesas por categoria
          pw.Text('Despesas por categoria',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.SizedBox(height: 8),
          if (catList.isEmpty)
            pw.Text('Sem despesas registradas no período.',
                style: const pw.TextStyle(color: gray, fontSize: 10))
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Categoria', 'Valor', '%'],
              headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF374151)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              oddRowDecoration:
                  pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
              data: [
                for (final e in catList)
                  [
                    e.name,
                    Money.format(e.amount),
                    catTotal == 0
                        ? '0%'
                        : '${((e.amount / catTotal) * 100).toStringAsFixed(0)}%',
                  ],
                ['Total', Money.format(catTotal), '100%'],
              ],
            ),

          pw.SizedBox(height: 16),

          // Situação do mês corrente
          pw.Text('Situação do mês corrente',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF9FAFB),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                kv('Receitas do mês', Money.format(monthSummary.incomeCents),
                    color: positive),
                kv('Despesas do mês', Money.format(monthSummary.expenseCents),
                    color: negative),
                kv('Resultado do mês', Money.format(monthSummary.resultCents),
                    color:
                        monthSummary.resultCents >= 0 ? positive : negative),
                kv('Comprometido', Money.format(monthSummary.committedIncomeCents)),
                kv('Comprometimento da renda',
                    Money.formatPercent(monthSummary.committedPercent)),
              ],
            ),
          ),

          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'O saldo em contas considera apenas contas incluídas no patrimônio, '
              'respeitando as reservas protegidas configuradas. Compras no cartão '
              'são contabilizadas como despesa econômica na data da compra e o '
              'pagamento da fatura como movimentação de caixa — sem dupla contagem.',
              style: const pw.TextStyle(color: gray, fontSize: 8, lineSpacing: 2),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
