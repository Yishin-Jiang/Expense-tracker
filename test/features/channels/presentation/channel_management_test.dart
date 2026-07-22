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

  testWidgets('user can create, rename, archive, and restore a channel', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const AccountingApp(initialLocation: '/categories'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('購物管道'));
    await tester.pumpAndSettle();
    expect(find.text('實體店面'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addChannelButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('channelNameField')), '外送平台');
    tester
        .widget<FilledButton>(find.byKey(const Key('saveChannelButton')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('外送平台'), findsOneWidget);

    final created = await (database.select(
      database.channels,
    )..where((row) => row.name.equals('外送平台'))).getSingle();
    var menu = find.byKey(Key('channelMenu-${created.id}'));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改名稱'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('channelNameField')), '校園外送');
    tester
        .widget<FilledButton>(find.byKey(const Key('saveChannelButton')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('校園外送'), findsOneWidget);

    menu = find.byKey(Key('channelMenu-${created.id}'));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '停用'));
    await tester.pumpAndSettle();
    expect(find.text('已停用的管道（1）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inactiveChannelsSection')));
    await tester.pumpAndSettle();
    final restore = find.byKey(Key('restoreChannel-${created.id}'));
    await tester.scrollUntilVisible(
      restore,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(find.text('使用中'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('custom active channel appears in the transaction form', (
    tester,
  ) async {
    await database
        .into(database.channels)
        .insert(ChannelsCompanion.insert(code: 'delivery', name: '外送平台'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const AccountingApp(initialLocation: '/transactions/new'),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('channelField'));
    await tester.scrollUntilVisible(
      field,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text('外送平台'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
