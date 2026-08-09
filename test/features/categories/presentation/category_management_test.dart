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

  tearDown(() => database.close());

  testWidgets('user can create, edit, archive, and restore a category', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const AccountingApp(initialLocation: '/categories'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分類管理'), findsOneWidget);
    expect(find.text('飲食'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pump();
    expect(find.text('新增類別'), findsWidgets);
    expect(find.text('分類管理'), findsNothing);
    await tester.enterText(find.byKey(const Key('categoryNameField')), '咖啡');
    await tester.tap(find.byKey(const Key('categoryParent-expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('飲食').last);
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const Key('saveCategoryButton'));
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

    expect(find.text('咖啡'), findsOneWidget);
    final created = await (database.select(
      database.categories,
    )..where((row) => row.name.equals('咖啡'))).getSingle();

    var categoryMenu = find.byKey(Key('categoryMenu-${created.id}'));
    await tester.scrollUntilVisible(
      categoryMenu,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(categoryMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameField')), '咖啡飲品');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: formScrollable.first,
    );
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('咖啡飲品'), findsOneWidget);

    categoryMenu = find.byKey(Key('categoryMenu-${created.id}'));
    await tester.scrollUntilVisible(
      categoryMenu,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(categoryMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    expect(find.textContaining('停用「咖啡飲品」'), findsOneWidget);
    await tester.tap(find.text('確認停用'));
    await tester.pumpAndSettle();
    expect(find.text('已停用・歷史資料保留'), findsOneWidget);

    await tester.scrollUntilVisible(
      categoryMenu,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(categoryMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新啟用'));
    await tester.pumpAndSettle();
    expect(find.text('記帳細項'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
