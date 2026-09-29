import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';

/// MoneyDisplay — exibe valores monetários com hierarquia tipográfica
/// e cor semântica automática (cap. 48/49).
class MoneyDisplay extends StatelessWidget {
  final int cents;
  final double fontSize;
  final FontWeight fontWeight;
  final bool signed;
  final bool colorize;
  final Color? color;
  final TextAlign align;

  const MoneyDisplay(
    this.cents, {
    super.key,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w700,
    this.signed = false,
    this.colorize = false,
    this.color,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    var c = color;
    if (c == null && colorize) {
      c = cents > 0
          ? AppColors.positive
          : cents < 0
              ? AppColors.negative
              : Theme.of(context).textTheme.bodyLarge?.color;
    }
    final text = signed && cents > 0 ? '+ ' : '';
    return Text(
      '$text${Money.format(cents)}',
      textAlign: align,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: c,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// FinancialCard — contêiner base do Design System.
class FinancialCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final double radius;

  const FinancialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.gradient,
    this.border,
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? (isDark ? AppColors.darkCard : AppColors.lightCard))
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Rótulo de seção com ação opcional.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Text(title,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) trailing!,
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// StatusBadge — rótulo colorido de status (cap. 48).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// CategoryBadge — chip com ícone/cor de categoria.
class CategoryBadge extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  const CategoryBadge({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(name,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Ícone circular colorido (avatar de categoria/conta).
class CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const CircleIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// BudgetProgress — barra de progresso de orçamento (cap. 26/48).
class BudgetProgress extends StatelessWidget {
  final double percent;
  final Color? color;
  final double height;
  const BudgetProgress({
    super.key,
    required this.percent,
    this.color,
    this.height = 8,
  });

  Color _autoColor() {
    if (percent >= 100) return AppColors.negative;
    if (percent >= 80) return AppColors.warning;
    return AppColors.positive;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? _autoColor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: (percent / 100).clamp(0, 1),
        minHeight: height,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.gray200,
        valueColor: AlwaysStoppedAnimation(c),
      ),
    );
  }
}

/// InsightCard — insight do Radar Financeiro (cap. 11/48).
class InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const InsightCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FinancialCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleIcon(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(message,
                    style: t.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.8),
                      height: 1.35,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// EmptyState — evita páginas mortas (cap. 76/48).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final secondary = t.bodyMedium?.color?.withValues(alpha: 0.7);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleIcon(icon: icon, color: AppColors.emerald, size: 72),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: secondary, height: 1.4)),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 240,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton — placeholder de carregamento (cap. 77/48).
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 12});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final base = isDark ? AppColors.surfaceDark : AppColors.gray200;
        final highlight = isDark ? AppColors.darkCard : AppColors.gray100;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: Color.lerp(base, highlight, _c.value),
          ),
        );
      },
    );
  }
}

/// Skeleton de lista para telas.
class ListSkeleton extends StatelessWidget {
  final int count;
  const ListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Skeleton(height: 42, width: 42, radius: 21),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 13, width: 160),
                    SizedBox(height: 8),
                    Skeleton(height: 11, width: 100),
                  ],
                ),
              ),
              Skeleton(height: 14, width: 70),
            ],
          ),
        ),
      ),
    );
  }
}

/// ConfirmDialog — confirmação de ações críticas (cap. 79/48).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return AlertDialog(
        title: Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        content: Text(message, style: t.bodyMedium?.copyWith(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? AppColors.negative : AppColors.emerald,
              minimumSize: const Size(100, 44),
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Toast — feedback rápido (cap. 48/78).
void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: error ? AppColors.negative : null,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}
