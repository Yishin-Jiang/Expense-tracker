import 'dart:io';

import 'package:accounting_app/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('database operations', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('creates default categories and channels once', () async {
      final categories = await database.select(database.categories).get();
      final channels = await database.select(database.channels).get();
      final subscriptions = await database.select(database.subscriptions).get();

      expect(
        categories.map((item) => item.name),
        containsAll(['飲食', '早餐', '午餐', '晚餐', '日用品', '房租', '交通', '薪資']),
      );
      expect(categories, hasLength(8));
      expect(
        channels.map((item) => item.code),
        containsAll(['physical_store', 'online']),
      );
      expect(channels, hasLength(2));
      expect(subscriptions, isEmpty);
      expect(database.schemaVersion, 2);
    });

    test('creates, updates, and soft deletes a transaction', () async {
      final category = await (database.select(
        database.categories,
      )..where((row) => row.name.equals('午餐'))).getSingle();
      final channel = await (database.select(
        database.channels,
      )..where((row) => row.code.equals('physical_store'))).getSingle();
      final occurredAt = DateTime.utc(2026, 7, 21, 12);

      final id = await database.transactionDao.createTransaction(
        TransactionsCompanion.insert(
          categoryId: category.id,
          channelId: Value(channel.id),
          type: 'expense',
          amount: 120,
          occurredAt: occurredAt,
          note: const Value('學餐'),
        ),
      );

      final created = await database.transactionDao.getTransaction(id);
      expect(created?.amount, 120);
      expect(created?.note, '學餐');

      await database.transactionDao.updateTransaction(
        created!.copyWith(amount: 130),
      );
      expect((await database.transactionDao.getTransaction(id))?.amount, 130);

      expect(await database.transactionDao.softDeleteTransaction(id), 1);
      expect(await database.transactionDao.getTransaction(id), null);
      expect(
        await database.transactionDao
            .watchTransactions(
              start: DateTime.utc(2026, 7),
              end: DateTime.utc(2026, 8),
            )
            .first,
        isEmpty,
      );
    });

    test('rejects zero-value transactions', () async {
      final category = await (database.select(
        database.categories,
      )..where((row) => row.name.equals('午餐'))).getSingle();

      expect(
        () => database.transactionDao.createTransaction(
          TransactionsCompanion.insert(
            categoryId: category.id,
            type: 'expense',
            amount: 0,
            occurredAt: DateTime.now().toUtc(),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('migrates an existing version 1 database without losing data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'accounting_app_migration_',
    );
    final file = File('${directory.path}${Platform.pathSeparator}migration.db');
    AppDatabase? first;
    AppDatabase? upgraded;
    try {
      first = AppDatabase.forTesting(NativeDatabase(file));
      final originalCategories = await first.select(first.categories).get();
      expect(originalCategories, hasLength(8));
      await first.customStatement('DROP TABLE subscriptions');
      await first.customStatement('PRAGMA user_version = 1');
      await first.close();
      first = null;

      upgraded = AppDatabase.forTesting(NativeDatabase(file));
      expect(await upgraded.select(upgraded.categories).get(), hasLength(8));
      expect(await upgraded.select(upgraded.subscriptions).get(), isEmpty);
    } finally {
      await first?.close();
      await upgraded?.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  });
}
