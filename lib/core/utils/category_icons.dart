import 'package:flutter/material.dart';

/// Categorias iniciais (cap. 40) e mapeamento de ícones.
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> _map = {
    'home': Icons.home_outlined,
    'restaurant': Icons.restaurant_outlined,
    'transport': Icons.directions_car_outlined,
    'health': Icons.favorite_border,
    'education': Icons.school_outlined,
    'family': Icons.family_restroom,
    'leisure': Icons.sports_esports_outlined,
    'dining': Icons.local_dining_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'subscriptions': Icons.autorenew,
    'services': Icons.handyman_outlined,
    'travel': Icons.flight_takeoff_outlined,
    'taxes': Icons.receipt_long_outlined,
    'insurance': Icons.shield_outlined,
    'debt': Icons.trending_down,
    'investment': Icons.trending_up,
    'salary': Icons.payments_outlined,
    'freelance': Icons.work_outline,
    'gift': Icons.card_giftcard_outlined,
    'other': Icons.more_horiz,
    'category': Icons.label_outline,
    'flag': Icons.flag_outlined,
  };

  static IconData get(String name) => _map[name] ?? Icons.label_outline;

  /// Definição das categorias iniciais (nome, ícone, cor, isIncome).
  static List<({String name, String icon, int color, bool isIncome})>
      get defaults => const [
            (name: 'Moradia', icon: 'home', color: 0xFF6366F1, isIncome: false),
            (name: 'Alimentação', icon: 'restaurant', color: 0xFFF59E0B, isIncome: false),
            (name: 'Transporte', icon: 'transport', color: 0xFF3B82F6, isIncome: false),
            (name: 'Saúde', icon: 'health', color: 0xFFEF4444, isIncome: false),
            (name: 'Educação', icon: 'education', color: 0xFF8B5CF6, isIncome: false),
            (name: 'Filhos/Família', icon: 'family', color: 0xFFEC4899, isIncome: false),
            (name: 'Lazer', icon: 'leisure', color: 0xFF14B8A6, isIncome: false),
            (name: 'Restaurantes', icon: 'dining', color: 0xFFF97316, isIncome: false),
            (name: 'Compras', icon: 'shopping', color: 0xFFA855F7, isIncome: false),
            (name: 'Assinaturas', icon: 'subscriptions', color: 0xFF0EA5E9, isIncome: false),
            (name: 'Serviços', icon: 'services', color: 0xFF64748B, isIncome: false),
            (name: 'Viagens', icon: 'travel', color: 0xFF06B6D4, isIncome: false),
            (name: 'Impostos', icon: 'taxes', color: 0xFF78716C, isIncome: false),
            (name: 'Seguros', icon: 'insurance', color: 0xFF3F6212, isIncome: false),
            (name: 'Dívidas', icon: 'debt', color: 0xFFDC2626, isIncome: false),
            (name: 'Investimentos', icon: 'investment', color: 0xFF10B981, isIncome: false),
            (name: 'Outros', icon: 'other', color: 0xFF6B7280, isIncome: false),
            (name: 'Salário', icon: 'salary', color: 0xFF10B981, isIncome: true),
            (name: 'Freelance', icon: 'freelance', color: 0xFF22C55E, isIncome: true),
            (name: 'Presentes', icon: 'gift', color: 0xFF84CC16, isIncome: true),
          ];
}
