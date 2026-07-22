import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  testWidgets('user can create, edit, and delete an expense', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const AccountingApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('記帳'));
    await tester.pumpAndSettle();
    expect(find.text('新增一筆'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amountField')), '120');
    await tester.tap(find.byKey(const Key('category-expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('午餐').last);
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const Key('saveTransactionButton'));
    final formScrollable = find.descendant(
      of: find.byType(Form),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: formScrollable.first,
    );
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('交易明細'), findsOneWidget);
    expect(find.text('− NT\$ 120'), findsOneWidget);
    expect(await database.select(database.transactions).get(), hasLength(1));

    await tester.tap(find.byKey(const Key('editTransactionButton')));
    await tester.pumpAndSettle();
    expect(find.text('修改記錄'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amountField')), '180');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: formScrollable.first,
    );
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('− NT\$ 180'), findsOneWidget);

    await tester.tap(find.byKey(const Key('deleteTransactionButton')));
    await tester.pumpAndSettle();
    expect(find.text('刪除這筆記錄？'), findsOneWidget);
    await tester.tap(find.text('確認刪除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('settingsButton')), findsOneWidget);
    final deleted = await database.select(database.transactions).getSingle();
    expect(deleted.deletedAt, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
