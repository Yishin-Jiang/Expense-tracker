import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/core/utils/taipei_time.dart';
import 'package:accounting_app/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:accounting_app/features/transactions/data/drift_transaction_repository.dart';
import 'package:accounting_app/features/transactions/domain/transaction.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('user can search, combine filters, and open a transaction', (
    tester,
  ) async {
    final seeded = await _seedTransactions(database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          subscriptionTodayProvider.overrideWithValue(DateTime(2026, 7, 22)),
        ],
        child: const AccountingApp(initialLocation: '/transactions/history'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('交易紀錄'), findsOneWidget);
    expect(find.text('共 4 筆'), findsOneWidget);
    expect(find.text('NT\$ 819'), findsOneWidget);
    expect(find.text('NT\$ 3,000'), findsOneWidget);
    expect(find.textContaining('不應顯示'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('transactionSearchField')),
      'Spotify',
    );
    await tester.pumpAndSettle();
    expect(find.text('共 1 筆'), findsOneWidget);
    expect(find.textContaining('Spotify'), findsWidgets);
    expect(find.textContaining('學校午餐'), findsNothing);

    await tester.enterText(find.byKey(const Key('transactionSearchField')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transactionFilterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filterTransactionType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('支出').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filterCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('飲食（含子類別）'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('applyTransactionFiltersButton')));
    await tester.pumpAndSettle();

    expect(find.text('共 1 筆'), findsOneWidget);
    expect(find.textContaining('學校午餐'), findsOneWidget);
    expect(find.textContaining('衛生紙'), findsNothing);

    await tester.tap(
      find.byKey(Key('historyTransaction-${seeded.lunchTransactionId}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('交易明細'), findsOneWidget);
    expect(find.text('− NT\$ 120'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<({int lunchTransactionId})> _seedTransactions(
  AppDatabase database,
) async {
  await database.customSelect('SELECT 1').get();
  final categories = await database.select(database.categories).get();
  final channels = await database.select(database.channels).get();
  final lunch = categories.singleWhere((item) => item.name == '午餐');
  final supplies = categories.singleWhere((item) => item.name == '日用品');
  final salary = categories.singleWhere((item) => item.name == '薪資');
  final physical = channels.singleWhere(
    (item) => item.code == 'physical_store',
  );
  final online = channels.singleWhere((item) => item.code == 'online');
  final repository = DriftTransactionRepository(database);

  Future<TransactionRecord> add({
    required int categoryId,
    required TransactionType type,
    required int amount,
    required DateTime date,
    required String note,
    int? channelId,
    TransactionSource source = TransactionSource.manual,
  }) => repository.createTransaction(
    TransactionInput(
      categoryId: categoryId,
      channelId: channelId,
      type: type,
      amount: amount,
      occurredAt: toUtcFromTaipei(date),
      note: note,
      source: source,
    ),
  );

  final lunchTransaction = await add(
    categoryId: lunch.id,
    channelId: physical.id,
    type: TransactionType.expense,
    amount: 120,
    date: DateTime(2026, 7, 10, 12),
    note: '學校午餐',
  );
  await add(
    categoryId: supplies.id,
    channelId: online.id,
    type: TransactionType.expense,
    amount: 500,
    date: DateTime(2026, 7, 21, 18),
    note: '衛生紙',
  );
  await add(
    categoryId: salary.id,
    type: TransactionType.income,
    amount: 3000,
    date: DateTime(2026, 7, 22, 9),
    note: '打工收入',
  );
  await add(
    categoryId: supplies.id,
    channelId: online.id,
    type: TransactionType.expense,
    amount: 199,
    date: DateTime(2026, 8, 1, 12),
    note: 'Spotify 自動扣款',
    source: TransactionSource.subscription,
  );
  final deleted = await add(
    categoryId: lunch.id,
    type: TransactionType.expense,
    amount: 999,
    date: DateTime(2026, 7, 1, 12),
    note: '不應顯示',
  );
  await repository.deleteTransaction(deleted.id);
  return (lunchTransactionId: lunchTransaction.id);
}
