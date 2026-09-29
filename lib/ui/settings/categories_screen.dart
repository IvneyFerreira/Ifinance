import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Gerenciar categorias (cap. 14): criar, editar e arquivar/desarquivar.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _income = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final list = c.categories
        .where((x) => x.isIncome == _income)
        .toList()
      ..sort((a, b) => (a.archived ? 1 : 0).compareTo(b.archived ? 1 : 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null, _income),
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Despesas')),
              ButtonSegment(value: true, label: Text('Receitas')),
            ],
            selected: {_income},
            onSelectionChanged: (s) => setState(() => _income = s.first),
          ),
          const SizedBox(height: 16),
          ...list.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FinancialCard(
                  onTap: () => _edit(context, cat, _income),
                  child: Row(
                    children: [
                      CircleIcon(
                          icon: CategoryIcons.get(cat.iconName),
                          color: Color(cat.colorValue),
                          size: 42),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(cat.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cat.archived
                                        ? AppColors.gray400
                                        : null)),
                      ),
                      if (cat.archived)
                        const StatusBadge(
                            label: 'Arquivada', color: AppColors.gray400),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: AppColors.gray400),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _edit(BuildContext context, Category? cat, bool isIncome) {
    final c = context.read<AppController>();
    final nameCtrl = TextEditingController(text: cat?.name ?? '');
    var color = cat?.colorValue ?? AppColors.emerald.toARGB32();
    var icon = cat?.iconName ?? 'category';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat == null ? 'Nova categoria' : 'Editar categoria',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 16),
                  Text('Ícone',
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _iconChoices.map((ic) {
                        final sel = ic == icon;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setSheet(() => icon = ic),
                            child: CircleAvatar(
                              backgroundColor: sel
                                  ? Color(color)
                                  : Color(color).withValues(alpha: 0.15),
                              child: Icon(CategoryIcons.get(ic),
                                  color: sel ? Colors.white : Color(color),
                                  size: 20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Cor',
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _colorChoices.map((co) {
                      final sel = co == color;
                      return GestureDetector(
                        onTap: () => setSheet(() => color = co),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(co),
                            shape: BoxShape.circle,
                            border: sel
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            await c.saveCategory(Category(
                              id: cat?.id ?? c.repo.newId(),
                              userId: c.user!.id,
                              name: name,
                              iconName: icon,
                              colorValue: color,
                              isIncome: cat?.isIncome ?? isIncome,
                              archived: cat?.archived ?? false,
                              createdAt: cat?.createdAt ?? DateTime.now(),
                            ));
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Salvar'),
                        ),
                      ),
                      if (cat != null) ...[
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () async {
                            await c.saveCategory(
                                cat.copyWith(archived: !cat.archived));
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(cat.archived ? 'Desarquivar' : 'Arquivar'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  static const _iconChoices = [
    'category', 'restaurant', 'local_grocery_store', 'directions_car',
    'home', 'bolt', 'health_and_safety', 'school', 'movie', 'shopping_bag',
    'pets', 'flight', 'fitness_center', 'phone_iphone', 'payments',
    'savings', 'work', 'redeem', 'attach_money', 'card_giftcard',
  ];

  static const _colorChoices = [
    0xFF10B981, 0xFF3B82F6, 0xFF8B5CF6, 0xFFF59E0B, 0xFFEF4444,
    0xFFEC4899, 0xFF14B8A6, 0xFF6366F1, 0xFF84CC16, 0xFF6B7280,
  ];
}
