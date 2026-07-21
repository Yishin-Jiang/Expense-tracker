import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/features/transactions/data/drift_transaction_repository.dart';
import 'package:accounting_app/features/transactions/domain/transaction.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftTransactionRepository repository;
  late int lunchCategoryId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTransactionRepository(database);
    lunchCategoryId = (await (database.select(
      database.categories,
    )..where((row) => row.name.equals('午餐'))).getSingle()).id;
  });

  tearDown(() => database.close());

  test(
    'repository creates, updates, and soft deletes without exposing Drift',
    () async {
      final created = await repository.createTransaction(
        TransactionInput(
          categoryId: lunchCategoryId,
          type: TransactionType.expense,
          amount: 120,
          occurredAt: DateTime.utc(2026, 7, 21, 4),
          note: ' 學餐 ',
        ),
      );
      expect(created.amount, 120);
      expect(created.note, '學餐');

      final updated = await repository.updateTransaction(
        created.id,
        TransactionInput(
          categoryId: lunchCategoryId,
          type: TransactionType.expense,
          amount: 130,
          occurredAt: created.occurredAt,
        ),
      );
      expect(updated.amount, 130);

      await repository.deleteTransaction(created.id);
      expect(await repository.getTransaction(created.id), null);
    },
  );

  test('daily summary uses Asia Taipei calendar boundaries', () async {
    await repository.createTransaction(
      TransactionInput(
        categoryId: lunchCategoryId,
        type: TransactionType.expense,
        amount: 120,
        occurredAt: DateTime.utc(2026, 7, 20, 16, 30),
      ),
    );
    await repository.createTransaction(
      TransactionInput(
        categoryId: lunchCategoryId,
        type: TransactionType.income,
        amount: 500,
        occurredAt: DateTime.utc(2026, 7, 21, 15, 59),
      ),
    );
    await repository.createTransaction(
      TransactionInput(
        categoryId: lunchCategoryId,
        type: TransactionType.expense,
        amount: 999,
        occurredAt: DateTime.utc(2026, 7, 21, 16),
      ),
    );

    final summary = await repository
        .watchDailySummary(DateTime(2026, 7, 21))
        .first;
    expect(summary.transactionCount, 2);
    expect(summary.expense, 120);
    expect(summary.income, 500);
    expect(summary.balance, 380);
  });
}
