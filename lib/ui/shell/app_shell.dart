import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../calendar/calendar_screen.dart';
import '../cards/cards_screen.dart';
import '../dashboard/home_screen.dart';
import '../goals/goals_screen.dart';
import '../planning/planning_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/transactions_screen.dart';
import 'quick_add.dart';

/// Estrutura principal responsiva (cap. 5/6):
/// - Mobile: menu inferior (Início, Movimentações, +, Planejar, Metas/Perfil)
/// - Desktop: sidebar à esquerda
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    TransactionsScreen(),
    PlanningScreen(),
    GoalsScreen(),
    ProfileScreen(),
  ];

  static const _destinations = <((IconData, IconData), String)>[
    ((Icons.home_outlined, Icons.home), 'Início'),
    ((Icons.swap_vert_outlined, Icons.swap_vert), 'Movimentações'),
    ((Icons.calendar_month_outlined, Icons.calendar_month), 'Planejar'),
    ((Icons.flag_outlined, Icons.flag), 'Metas'),
    ((Icons.person_outline, Icons.person), 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppController>().syncNotifications();
    });
  }

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showQuickAdd(context),
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Registrar'),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => showQuickAdd(context),
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.add, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 66,
        color: Theme.of(context).cardTheme.color,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            _navHalf(0),
            _navHalf(1),
            const SizedBox(width: 64),
            _navHalf(2),
            _navHalf(3),
          ],
        ),
      ),
    );
  }

  Widget _navHalf(int i) {
    return Expanded(
      child: _NavItem(
        icon: _destinations[i].$1,
        label: _destinations[i].$2,
        selected: _index == i,
        onTap: () => setState(() => _index = i),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final (IconData, IconData) icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.emerald
        : Theme.of(context).textTheme.bodySmall?.color;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? icon.$2 : icon.$1, color: color, size: 24),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

/// Sidebar desktop (cap. 6).
class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = const [
      (Icons.dashboard_outlined, 'Visão Geral'),
      (Icons.swap_vert, 'Movimentações'),
      (Icons.calendar_month_outlined, 'Planejar'),
      (Icons.flag_outlined, 'Metas'),
      (Icons.person_outline, 'Perfil'),
    ];
    return Container(
      width: 248,
      color: Theme.of(context).cardTheme.color,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Center(
                      child: Text('N',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('NeyFlow',
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Financial Command Center',
                  style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(height: 18),
            ...List.generate(items.length, (i) {
              final selected = index == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Material(
                  color: selected
                      ? AppColors.emerald.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(items[i].$1,
                              size: 20,
                              color: selected
                                  ? AppColors.emerald
                                  : t.bodyMedium?.color),
                          const SizedBox(width: 12),
                          Text(items[i].$2,
                              style: t.bodyMedium?.copyWith(
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? AppColors.emerald : null,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
