import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/core/utils/taipei_time.dart';
import 'package:accounting_app/features/analysis/presentation/providers/analysis_providers.dart';
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

  testWidgets('analysis shows totals, comparison, categories, and channels', (
    tester,
  ) async {
    final seeded = await _seedAnalysisTransactions(database);
    await _pumpAnalysis(tester, database);

    expect(find.text('2026 年 7 月'), findsOneWidget);
    expect(find.text('NT\$ 3,000'), findsOneWidget);
    expect(find.text('NT\$ 1,000'), findsWidgets);
    expect(find.text('NT\$ 2,000'), findsOneWidget);
    expect(find.textContaining('增加 25.0%'), findsOneWidget);
    expect(find.textContaining('上月支出 NT\$ 800'), findsOneWidget);

    expect(find.byKey(const Key('analysisDayBar-10')), findsOneWidget);
    expect(find.byKey(const Key('analysisDayBar-21')), findsOneWidget);

    final foodCategory = find.byKey(
      Key('analysisCategoryGroup-${seeded.foodCategoryId}'),
    );
    await tester.ensureVisible(foodCategory);
    await tester.pumpAndSettle();
    expect(find.text('飲食'), findsOneWidget);
    expect(find.text('50.0%'), findsWidgets);
    expect(find.text('實體店面'), findsOneWidget);
    expect(find.textContaining('30.0%・NT\$ 300'), findsOneWidget);
    expect(find.text('網購'), findsOneWidget);
    expect(find.textContaining('70.0%・NT\$ 700'), findsOneWidget);

    await tester.tap(foodCategory);
    await tester.pumpAndSettle();
    final lunchCategory = find.byKey(
      Key('analysisCategory-${seeded.lunchCategoryId}'),
    );
    expect(lunchCategory, findsOneWidget);
    await tester.tap(lunchCategory);
    await tester.pumpAndSettle();
    expect(find.text('午餐交易'), findsOneWidget);
    expect(find.text('學校午餐'), findsOneWidget);
    expect(find.text('朋友聚餐'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('analysis switches to the previous month', (tester) async {
    await _seedAnalysisTransactions(database);
    await _pumpAnalysis(tester, database);

    await tester.tap(find.byKey(const Key('analysisPreviousMonthButton')));
    await tester.pumpAndSettle();
    expect(find.text('2026 年 6 月'), findsOneWidget);
    expect(find.text('NT\$ 800'), findsWidgets);
    expect(find.text('NT\$ 0'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpAnalysis(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        analysisTodayProvider.overrideWithValue(DateTime(2026, 7, 22)),
      ],
      child: const AccountingApp(initialLocation: '/analysis'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<({int foodCategoryId, int lunchCategoryId})> _seedAnalysisTransactions(
  AppDatabase database,
) async {
  await database.customSelect('SELECT 1').get();
  final categories = await database.select(database.categories).get();
  final channels = await database.select(database.channels).get();
  final lunch = categories.singleWhere((item) => item.name == '午餐');
  final food = categories.singleWhere((item) => item.name == '飲食');
  final supplies = categories.singleWhere((item) => item.name == '日用品');
  final salary = categories.singleWhere((item) => item.name == '薪資');
  final physical = channels.singleWhere(
    (item) => item.code == 'physical_store',
  );
  final online = channels.singleWhere((item) => item.code == 'online');
  final repository = DriftTransactionRepository(database);

  Future<void> add({
    required int categoryId,
    required TransactionType type,
    required int amount,
    required DateTime date,
    required String note,
    int? channelId,
  }) async {
    await repository.createTransaction(
      TransactionInput(
        categoryId: categoryId,
        channelId: channelId,
        type: type,
        amount: amount,
        occurredAt: toUtcFromTaipei(date),
        note: note,
      ),
    );
  }

  await add(
    categoryId: lunch.id,
    channelId: physical.id,
    type: TransactionType.expense,
    amount: 300,
    date: DateTime(2026, 7, 10, 12),
    note: '學校午餐',
  );
  await add(
    categoryId: lunch.id,
    channelId: online.id,
    type: TransactionType.expense,
    amount: 200,
    date: DateTime(2026, 7, 20, 18),
    note: '朋友聚餐',
  );
  await add(
    categoryId: supplies.id,
    channelId: online.id,
    type: TransactionType.expense,
    amount: 500,
    date: DateTime(2026, 7, 21, 15),
    note: '租屋用品',
  );
  await add(
    categoryId: salary.id,
    type: TransactionType.income,
    amount: 3000,
    date: DateTime(2026, 7, 5, 9),
    note: '打工薪資',
  );
  await add(
    categoryId: lunch.id,
    channelId: physical.id,
    type: TransactionType.expense,
    amount: 800,
    date: DateTime(2026, 6, 12, 18),
    note: '六月聚餐',
  );

  return (foodCategoryId: food.id, lunchCategoryId: lunch.id);
}
