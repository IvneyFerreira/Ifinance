import 'package:flutter/material.dart';

import '../../core/finance/finance_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/money.dart';

/// Gráfico de barras Receitas x Despesas (cap. 10) — simples, sem poluição.
class IncomeExpenseChart extends StatelessWidget {
  final List<FlowPoint> points;
  final double height;
  const IncomeExpenseChart({super.key, required this.points, this.height = 160});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxValue = points
        .expand((p) => [p.incomeCents, p.expenseCents])
        .fold<int>(1, (a, b) => b > a ? b : a);
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final incomeH = (p.incomeCents / maxValue) * (height - 34);
          final expenseH = (p.expenseCents / maxValue) * (height - 34);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bar(incomeH, AppColors.positive),
                        const SizedBox(width: 3),
                        _bar(expenseH, AppColors.negativeSoft),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateHelpers.monthLabel(p.month).substring(0, 3),
                    style: t.bodySmall?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bar(double h, Color color) => Container(
        width: 10,
        height: h < 2 ? 2 : h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

/// Gráfico de projeção de saldo (cap. 25) com destaque para dias críticos.
class ProjectionChart extends StatelessWidget {
  final List<ProjectionPoint> points;
  final double height;
  const ProjectionChart({super.key, required this.points, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _ProjectionPainter(
          points: points,
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ProjectionPainter extends CustomPainter {
  final List<ProjectionPoint> points;
  final bool isDark;
  _ProjectionPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.balanceCents).toList();
    var maxV = values.reduce((a, b) => a > b ? a : b);
    var minV = values.reduce((a, b) => a < b ? a : b);
    if (minV > 0) minV = 0;
    if (maxV == minV) maxV = minV + 1;
    final range = (maxV - minV).toDouble();

    double yFor(int v) =>
        size.height - ((v - minV) / range) * (size.height - 16) - 8;
    double xFor(int i) => (i / (points.length - 1)) * size.width;

    // Grade base
    final gridPaint = Paint()
      ..color = (isDark ? AppColors.darkBorder : AppColors.lightBorder)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, yFor(0)), Offset(size.width, yFor(0)), gridPaint);

    // Área + linha
    final path = Path();
    path.moveTo(xFor(0), yFor(points[0].balanceCents));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(xFor(i), yFor(points[i].balanceCents));
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.emerald.withValues(alpha: 0.28),
            AppColors.emerald.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.emerald
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Destaca pontos negativos
    for (var i = 0; i < points.length; i++) {
      if (points[i].balanceCents < 0) {
        canvas.drawCircle(
          Offset(xFor(i), yFor(points[i].balanceCents)),
          3.5,
          Paint()..color = AppColors.negative,
        );
      }
    }

    // Menor saldo
    final minIndex = values.indexOf(values.reduce((a, b) => a < b ? a : b));
    canvas.drawCircle(
      Offset(xFor(minIndex), yFor(values[minIndex])),
      4.5,
      Paint()..color = values[minIndex] < 0 ? AppColors.negative : AppColors.info,
    );
  }

  @override
  bool shouldRepaint(covariant _ProjectionPainter old) => true;
}

/// Diálogo "Ver cálculo" (cap. 39/4).
Future<void> showCalcExplanation(
    BuildContext context, CalcExplanation explanation) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerTheme.color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Ver cálculo',
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(explanation.title,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              ...explanation.components.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Text(c.isSubtraction ? '− ' : '+ ',
                            style: TextStyle(
                                color: c.isSubtraction
                                    ? AppColors.negative
                                    : AppColors.positive,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        Expanded(child: Text(c.label, style: t.bodyMedium)),
                        Text(Money.format(c.amountCents.abs()),
                            style: t.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text('= ${explanation.title}',
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Text(Money.format(explanation.resultCents),
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: explanation.resultCents >= 0
                            ? AppColors.positive
                            : AppColors.negative,
                      )),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Estilos auxiliares.
const double kCardGap = 14;
