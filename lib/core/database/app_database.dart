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

@DriftDatabase(
  tables: [Categories, Channels, Transactions],
  daos: [CategoryDao, ChannelDao, TransactionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

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
      await _seedDefaults();
    },
    onUpgrade: (migrator, from, to) async {
      // Future schema changes are added here, one version at a time.
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'accounting.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
