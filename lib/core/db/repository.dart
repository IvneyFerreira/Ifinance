import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'collection.dart';
import 'hive_db.dart';

/// Repositório central: encapsula o acesso a dados (acesso a dados separado
/// da UI e das regras financeiras — cap. 56).
///
/// Responsabilidades:
/// - Fornecer coleções tipadas por entidade;
/// - Registrar AuditLog em operações críticas (cap. 69);
/// - Nunca duplicar regras financeiras (essas vivem no FinanceEngine).
class Repository {
  final _uuid = const Uuid();

  late final Collection<AppUser> users = Collection(
    boxName: Db.users,
    fromMap: AppUser.fromMap,
    toMap: (u) => u.toMap(),
    idOf: (u) => u.id,
  );

  late final Collection<UserSettings> settings = Collection(
    boxName: Db.settings,
    fromMap: UserSettings.fromMap,
    toMap: (s) => s.toMap(),
    idOf: (s) => s.userId,
    userIdOf: (s) => s.userId,
  );

  late final Collection<Account> accounts = Collection(
    boxName: Db.accounts,
    fromMap: Account.fromMap,
    toMap: (a) => a.toMap(),
    idOf: (a) => a.id,
    userIdOf: (a) => a.userId,
  );

  late final Collection<Category> categories = Collection(
    boxName: Db.categories,
    fromMap: Category.fromMap,
    toMap: (c) => c.toMap(),
    idOf: (c) => c.id,
    userIdOf: (c) => c.userId,
  );

  late final Collection<Transaction> transactions = Collection(
    boxName: Db.transactions,
    fromMap: Transaction.fromMap,
    toMap: (t) => t.toMap(),
    idOf: (t) => t.id,
    userIdOf: (t) => t.userId,
  );

  late final Collection<CreditCard> cards = Collection(
    boxName: Db.cards,
    fromMap: CreditCard.fromMap,
    toMap: (c) => c.toMap(),
    idOf: (c) => c.id,
    userIdOf: (c) => c.userId,
  );

  late final Collection<CardPurchase> purchases = Collection(
    boxName: Db.purchases,
    fromMap: CardPurchase.fromMap,
    toMap: (p) => p.toMap(),
    idOf: (p) => p.id,
    userIdOf: (p) => p.userId,
  );

  late final Collection<Installment> installments = Collection(
    boxName: Db.installments,
    fromMap: Installment.fromMap,
    toMap: (i) => i.toMap(),
    idOf: (i) => i.id,
    userIdOf: (i) => i.userId,
  );

  late final Collection<Invoice> invoices = Collection(
    boxName: Db.invoices,
    fromMap: Invoice.fromMap,
    toMap: (i) => i.toMap(),
    idOf: (i) => i.id,
    userIdOf: (i) => i.userId,
  );

  late final Collection<RecurringRule> recurring = Collection(
    boxName: Db.recurring,
    fromMap: RecurringRule.fromMap,
    toMap: (r) => r.toMap(),
    idOf: (r) => r.id,
    userIdOf: (r) => r.userId,
  );

  late final Collection<Budget> budgets = Collection(
    boxName: Db.budgets,
    fromMap: Budget.fromMap,
    toMap: (b) => b.toMap(),
    idOf: (b) => b.id,
    userIdOf: (b) => b.userId,
  );

  late final Collection<Goal> goals = Collection(
    boxName: Db.goals,
    fromMap: Goal.fromMap,
    toMap: (g) => g.toMap(),
    idOf: (g) => g.id,
    userIdOf: (g) => g.userId,
  );

  late final Collection<GoalContribution> contributions = Collection(
    boxName: Db.goalContributions,
    fromMap: GoalContribution.fromMap,
    toMap: (c) => c.toMap(),
    idOf: (c) => c.id,
    userIdOf: (c) => c.userId,
  );

  late final Collection<Asset> assets = Collection(
    boxName: Db.assets,
    fromMap: Asset.fromMap,
    toMap: (a) => a.toMap(),
    idOf: (a) => a.id,
    userIdOf: (a) => a.userId,
  );

  late final Collection<Liability> liabilities = Collection(
    boxName: Db.liabilities,
    fromMap: Liability.fromMap,
    toMap: (l) => l.toMap(),
    idOf: (l) => l.id,
    userIdOf: (l) => l.userId,
  );

  late final Collection<Subscription> subscriptions = Collection(
    boxName: Db.subscriptions,
    fromMap: Subscription.fromMap,
    toMap: (s) => s.toMap(),
    idOf: (s) => s.id,
    userIdOf: (s) => s.userId,
  );

  late final Collection<AppNotification> notifications = Collection(
    boxName: Db.notifications,
    fromMap: AppNotification.fromMap,
    toMap: (n) => n.toMap(),
    idOf: (n) => n.id,
    userIdOf: (n) => n.userId,
  );

  late final Collection<AuditLog> audits = Collection(
    boxName: Db.audits,
    fromMap: AuditLog.fromMap,
    toMap: (a) => a.toMap(),
    idOf: (a) => a.id,
    userIdOf: (a) => a.userId,
  );

  late final Collection<Simulation> simulations = Collection(
    boxName: Db.simulations,
    fromMap: Simulation.fromMap,
    toMap: (s) => s.toMap(),
    idOf: (s) => s.id,
    userIdOf: (s) => s.userId,
  );

  late final Collection<Attachment> attachments = Collection(
    boxName: Db.attachments,
    fromMap: Attachment.fromMap,
    toMap: (a) => a.toMap(),
    idOf: (a) => a.id,
    userIdOf: (a) => a.userId,
  );

  String newId() => _uuid.v4();

  Future<void> log(String userId, String action, String entity,
      {String? entityId, String details = ''}) async {
    await audits.put(AuditLog(
      id: newId(),
      userId: userId,
      action: action,
      entity: entity,
      entityId: entityId,
      details: details,
      createdAt: DateTime.now(),
    ));
  }
}
