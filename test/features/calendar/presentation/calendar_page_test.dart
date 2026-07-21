import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/core/utils/taipei_time.dart';
import 'package:accounting_app/features/calendar/presentation/providers/calendar_providers.dart';
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

  testWidgets('calendar shows month totals and selected day transactions', (
    tester,
  ) async {
    await _seedCalendarTransactions(database);
    await _pumpCalendar(tester, database);

    expect(find.text('2026 年 7 月'), findsOneWidget);
    expect(find.text('NT\$ 420'), findsOneWidget);
    expect(find.text('NT\$ 2,000'), findsOneWidget);
    expect(find.textContaining('2 筆・支出 NT\$ 120'), findsOneWidget);
    expect(find.textContaining('學校午餐'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendarDay-2026-7-10')));
    await tester.pumpAndSettle();
    expect(find.text('7 月 10 日紀錄'), findsOneWidget);
    expect(find.textContaining('1 筆・支出 NT\$ 300'), findsOneWidget);
    expect(find.textContaining('月初聚餐'), findsOneWidget);

    final addButton = find.byKey(const Key('addTransactionForDateButton'));
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.text('新增一筆'), findsOneWidget);
    expect(find.text('2026 / 07 / 10'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('calendar switches month and keeps data separated', (
    tester,
  ) async {
    await _seedCalendarTransactions(database);
    await _pumpCalendar(tester, database);

    await tester.tap(find.byKey(const Key('nextMonthButton')));
    await tester.pumpAndSettle();
    expect(find.text('2026 年 8 月'), findsOneWidget);
    expect(find.text('NT\$ 50'), findsOneWidget);
    expect(find.text('NT\$ 0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendarDay-2026-8-5')));
    await tester.pumpAndSettle();
    expect(find.text('8 月 5 日紀錄'), findsOneWidget);
    expect(find.textContaining('暑假點心'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpCalendar(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        calendarTodayProvider.overrideWithValue(DateTime(2026, 7, 21)),
      ],
      child: const AccountingApp(initialLocation: '/calendar'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _seedCalendarTransactions(AppDatabase database) async {
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
      categoryId: salary.id,
      type: TransactionType.income,
      amount: 2000,
      occurredAt: toUtcFromTaipei(DateTime(2026, 7, 21, 9)),
      note: '打工薪資',
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
      categoryId: lunch.id,
      type: TransactionType.expense,
      amount: 50,
      occurredAt: toUtcFromTaipei(DateTime(2026, 8, 5, 15)),
      note: '暑假點心',
    ),
  );
}
