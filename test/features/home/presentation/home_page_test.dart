import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/core/utils/taipei_time.dart';
import 'package:accounting_app/features/home/presentation/providers/home_providers.dart';
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

  testWidgets('home shows live monthly and daily summaries', (tester) async {
    await database.customSelect('SELECT 1').get();
    final categories = await database.select(database.categories).get();
    final lunch = categories.singleWhere((item) => item.name == '午餐');
    final salary = categories.singleWhere((item) => item.name == '薪資');
    final repository = DriftTransactionRepository(database);

    await repository.createTransaction(
      TransactionInput(
        categoryId: lunch.id,
        type: TransactionType.expense,
        amount: 120,
        occurredAt: toUtcFromTaipei(DateTime(2026, 7, 21, 12)),
        note: '學校午餐',
      ),
    );
    await repository.createTransaction(
      TransactionInput(
        categoryId: lunch.id,
        type: TransactionType.expense,
        amount: 300,
        occurredAt: toUtcFromTaipei(DateTime(2026, 7, 10, 18)),
        note: '月初聚餐',
      ),
    );
    await repository.createTransaction(
      TransactionInput(
        categoryId: salary.id,
        type: TransactionType.income,
        amount: 2000,
        occurredAt: toUtcFromTaipei(DateTime(2026, 7, 21, 9)),
        note: '打工薪資',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          currentTaipeiDateProvider.overrideWithValue(DateTime(2026, 7, 21)),
        ],
        child: const AccountingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7 月 21 日'), findsOneWidget);
    expect(find.text('NT\$ 420'), findsOneWidget);
    expect(find.textContaining('收入 NT\$ 2,000'), findsOneWidget);
    expect(find.textContaining('共 2 筆・支出 NT\$ 120'), findsOneWidget);
    expect(find.textContaining('學校午餐'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
