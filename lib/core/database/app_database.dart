import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('CategoryEntry')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get type => text().withDefault(const Constant('expense'))();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('expense', 'income', 'both'))",
  ];
}

@DataClassName('ChannelEntry')
class Channels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 1, max: 40).unique()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

@DataClassName('SubscriptionEntry')
class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get channelId => integer().nullable().references(Channels, #id)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get amount => integer()();
  TextColumn get billingCycle => text()();
  IntColumn get billingDay => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get nextBillingDate => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get autoCreateTransaction =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (amount > 0)',
    'CHECK (billing_day BETWEEN 1 AND 31)',
    "CHECK (billing_cycle IN ('monthly', 'quarterly', 'yearly'))",
  ];
}

@DataClassName('TransactionEntry')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get channelId => integer().nullable().references(Channels, #id)();
  TextColumn get type => text()();
  IntColumn get amount => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('expense', 'income'))",
    'CHECK (amount > 0)',
    "CHECK (source IN ('manual', 'subscription'))",
  ];
}

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<CategoryEntry>> watchAllCategories() {
    return (select(categories)..orderBy([
          (row) => OrderingTerm.asc(row.sortOrder),
          (row) => OrderingTerm.asc(row.name),
        ]))
        .watch();
  }

  Stream<List<CategoryEntry>> watchActiveCategories(String transactionType) {
    final query = select(categories)
      ..where(
        (row) =>
            row.isActive.equals(true) &
            (row.type.equals(transactionType) | row.type.equals('both')),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.name),
      ]);
    return query.watch();
  }

  Future<int> createCategory(CategoriesCompanion category) {
    return into(categories).insert(category);
  }

  Future<bool> updateCategory(CategoryEntry category) {
    return update(
      categories,
    ).replace(category.copyWith(updatedAt: DateTime.now().toUtc()));
  }

  Future<int> archiveCategory(int id) {
    return (update(categories)..where((row) => row.id.equals(id))).write(
      CategoriesCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<int> setCategoryActive(int id, bool isActive) {
    return (update(categories)..where((row) => row.id.equals(id))).write(
      CategoriesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}

@DriftAccessor(tables: [Channels])
class ChannelDao extends DatabaseAccessor<AppDatabase> with _$ChannelDaoMixin {
  ChannelDao(super.db);

  Stream<List<ChannelEntry>> watchActiveChannels() {
    return (select(
      channels,
    )..where((row) => row.isActive.equals(true))).watch();
  }
}

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Stream<List<TransactionEntry>> watchAllTransactions() {
    return (select(transactions)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
        .watch();
  }

  Stream<List<TransactionEntry>> watchTransactions({
    required DateTime start,
    required DateTime end,
  }) {
    final query = select(transactions)
      ..where(
        (row) =>
            row.deletedAt.isNull() &
            row.occurredAt.isBiggerOrEqualValue(start.toUtc()) &
            row.occurredAt.isSmallerThanValue(end.toUtc()),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]);
    return query.watch();
  }

  Future<TransactionEntry?> getTransaction(int id) {
    return (select(transactions)
          ..where((row) => row.id.equals(id) & row.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<int> createTransaction(TransactionsCompanion transaction) {
    return into(transactions).insert(transaction);
  }

  Future<bool> updateTransaction(TransactionEntry transaction) {
    return update(
      transactions,
    ).replace(transaction.copyWith(updatedAt: DateTime.now().toUtc()));
  }

  Future<int> updateTransactionFields(int id, TransactionsCompanion changes) {
    return (update(
      transactions,
    )..where((row) => row.id.equals(id))).write(changes);
  }

  Future<int> softDeleteTransaction(int id) {
    final now = DateTime.now().toUtc();
    return (update(transactions)..where((row) => row.id.equals(id))).write(
      TransactionsCompanion(updatedAt: Value(now), deletedAt: Value(now)),
    );
  }
}

@DriftAccessor(tables: [Subscriptions])
class SubscriptionDao extends DatabaseAccessor<AppDatabase>
    with _$SubscriptionDaoMixin {
  SubscriptionDao(super.db);

  Stream<List<SubscriptionEntry>> watchAllSubscriptions() {
    return (select(subscriptions)..orderBy([
          (row) => OrderingTerm.desc(row.isActive),
          (row) => OrderingTerm.asc(row.nextBillingDate),
          (row) => OrderingTerm.asc(row.name),
        ]))
        .watch();
  }

  Future<SubscriptionEntry?> getSubscription(int id) {
    return (select(
      subscriptions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<int> createSubscription(SubscriptionsCompanion subscription) {
    return into(subscriptions).insert(subscription);
  }

  Future<int> updateSubscriptionFields(int id, SubscriptionsCompanion changes) {
    return (update(
      subscriptions,
    )..where((row) => row.id.equals(id))).write(changes);
  }

  Future<int> setSubscriptionActive(int id, bool active) {
    return updateSubscriptionFields(
      id,
      SubscriptionsCompanion(
        isActive: Value(active),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<List<SubscriptionEntry>> getDueSubscriptions(DateTime end) {
    return (select(subscriptions)
          ..where(
            (row) =>
                row.isActive.equals(true) &
                row.autoCreateTransaction.equals(true) &
                row.nextBillingDate.isSmallerOrEqualValue(end.toUtc()),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.nextBillingDate)]))
        .get();
  }
}

@DriftDatabase(
  tables: [Categories, Channels, Subscriptions, Transactions],
  daos: [CategoryDao, ChannelDao, TransactionDao, SubscriptionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'CREATE INDEX idx_transactions_date '
        'ON transactions (occurred_at)',
      );
      await customStatement(
        'CREATE INDEX idx_transactions_type_date '
        'ON transactions (type, occurred_at)',
      );
      await customStatement(
        'CREATE INDEX idx_transactions_category '
        'ON transactions (category_id)',
      );
      await customStatement(
        'CREATE INDEX idx_subscriptions_next_billing '
        'ON subscriptions (is_active, next_billing_date)',
      );
      await _seedDefaults();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(subscriptions);
        await customStatement(
          'CREATE INDEX idx_subscriptions_next_billing '
          'ON subscriptions (is_active, next_billing_date)',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaults() async {
    final foodId = await into(categories).insert(
      CategoriesCompanion.insert(
        name: '飲食',
        type: const Value('expense'),
        icon: const Value('restaurant'),
        color: const Value('#C9E5D4'),
        sortOrder: const Value(10),
      ),
    );

    await batch((batch) {
      batch.insertAll(categories, [
        CategoriesCompanion.insert(
          parentId: Value(foodId),
          name: '早餐',
          icon: const Value('breakfast_dining'),
          color: const Value('#C9E5D4'),
          sortOrder: const Value(11),
        ),
        CategoriesCompanion.insert(
          parentId: Value(foodId),
          name: '午餐',
          icon: const Value('lunch_dining'),
          color: const Value('#C9E5D4'),
          sortOrder: const Value(12),
        ),
        CategoriesCompanion.insert(
          parentId: Value(foodId),
          name: '晚餐',
          icon: const Value('dinner_dining'),
          color: const Value('#C9E5D4'),
          sortOrder: const Value(13),
        ),
        CategoriesCompanion.insert(
          name: '日用品',
          icon: const Value('shopping_basket'),
          color: const Value('#FAE0D9'),
          sortOrder: const Value(20),
        ),
        CategoriesCompanion.insert(
          name: '房租',
          icon: const Value('home'),
          color: const Value('#F5D16E'),
          sortOrder: const Value(30),
        ),
        CategoriesCompanion.insert(
          name: '交通',
          icon: const Value('directions_bus'),
          color: const Value('#C9E5D4'),
          sortOrder: const Value(40),
        ),
        CategoriesCompanion.insert(
          name: '薪資',
          type: const Value('income'),
          icon: const Value('payments'),
          color: const Value('#C9E5D4'),
          sortOrder: const Value(100),
        ),
      ]);
      batch.insertAll(channels, [
        ChannelsCompanion.insert(code: 'physical_store', name: '實體店面'),
        ChannelsCompanion.insert(code: 'online', name: '網購'),
      ]);
    });
  }

  Future<void> replaceAllData({
    required List<CategoryEntry> categories,
    required List<ChannelEntry> channels,
    required List<SubscriptionEntry> subscriptions,
    required List<TransactionEntry> transactions,
  }) {
    return transaction(() async {
      await _deleteAllData();
      await batch((batch) {
        batch.insertAll(this.channels, channels);
        batch.insertAll(
          this.categories,
          categories.where((item) => item.parentId == null).toList(),
        );
        batch.insertAll(
          this.categories,
          categories.where((item) => item.parentId != null).toList(),
        );
        batch.insertAll(this.subscriptions, subscriptions);
        batch.insertAll(this.transactions, transactions);
      });
    });
  }

  Future<void> clearAllDataAndRestoreDefaults() {
    return transaction(() async {
      await _deleteAllData();
      await _seedDefaults();
    });
  }

  Future<void> _deleteAllData() async {
    await delete(transactions).go();
    await delete(subscriptions).go();
    await (delete(categories)..where((row) => row.parentId.isNotNull())).go();
    await delete(categories).go();
    await delete(channels).go();
    await customStatement(
      "DELETE FROM sqlite_sequence WHERE name IN "
      "('categories', 'channels', 'subscriptions', 'transactions')",
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'accounting.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
