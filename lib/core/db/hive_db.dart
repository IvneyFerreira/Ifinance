import 'package:hive_flutter/hive_flutter.dart';

/// Nomes das caixas (boxes) do Hive. Cada coleção é persistida como
/// Map de string para dynamic serializado — sem necessidade de adapters
/// tipados, mantendo migração simples e consistente com "banco real" local.
class Db {
  Db._();

  static const String users = 'users';
  static const String settings = 'settings';
  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String cards = 'credit_cards';
  static const String purchases = 'card_purchases';
  static const String installments = 'installments';
  static const String invoices = 'invoices';
  static const String recurring = 'recurring_rules';
  static const String budgets = 'budgets';
  static const String goals = 'goals';
  static const String goalContributions = 'goal_contributions';
  static const String assets = 'assets';
  static const String liabilities = 'liabilities';
  static const String subscriptions = 'subscriptions';
  static const String notifications = 'notifications';
  static const String audits = 'audit_logs';
  static const String simulations = 'simulations';
  static const String attachments = 'attachments';

  static const List<String> all = [
    users, settings, accounts, categories, transactions, cards, purchases,
    installments, invoices, recurring, budgets, goals, goalContributions,
    assets, liabilities, subscriptions, notifications, audits, simulations,
    attachments,
  ];

  static Future<void> init() async {
    await Hive.initFlutter();
    for (final name in all) {
      await Hive.openBox<Map>(name);
    }
  }

  static Box<Map> box(String name) => Hive.box<Map>(name);
}
