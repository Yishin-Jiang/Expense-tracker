import 'package:accounting_app/app/app.dart';
import 'package:accounting_app/core/database/app_database.dart';
import 'package:accounting_app/core/database/database_provider.dart';
import 'package:accounting_app/features/subscriptions/data/drift_subscription_repository.dart';
import 'package:accounting_app/features/subscriptions/domain/subscription.dart';
import 'package:accounting_app/features/subscriptions/presentation/providers/subscription_providers.dart';
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

  testWidgets('user can create, edit, and archive a subscription', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          subscriptionTodayProvider.overrideWithValue(DateTime(2026, 7, 22)),
        ],
        child: const AccountingApp(initialLocation: '/subscriptions'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('還沒有訂閱項目'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addSubscriptionButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('subscriptionNameField')),
      'Spotify',
    );
    await tester.enterText(
      find.byKey(const Key('subscriptionAmountField')),
      '199',
    );
    await tester.tap(find.byKey(const Key('subscriptionCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日用品').last);
    await tester.pumpAndSettle();

    var saveButton = find.byKey(const Key('saveSubscriptionButton'));
    var formScrollable = find.descendant(
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

    expect(find.text('Spotify'), findsWidgets);
    expect(find.text('NT\$ 199'), findsWidgets);
    expect(find.textContaining('年度預估 NT\$ 2,388'), findsOneWidget);
    final created = await database.select(database.subscriptions).getSingle();

    var menu = find.byKey(Key('subscriptionMenu-${created.id}'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('subscriptionNameField')),
      'Spotify 學生方案',
    );
    await tester.enterText(
      find.byKey(const Key('subscriptionAmountField')),
      '99',
    );
    saveButton = find.byKey(const Key('saveSubscriptionButton'));
    formScrollable = find.descendant(
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

    expect(find.text('Spotify 學生方案'), findsWidgets);
    expect(find.textContaining('年度預估 NT\$ 1,188'), findsOneWidget);

    menu = find.byKey(Key('subscriptionMenu-${created.id}'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    expect(find.textContaining('停用「Spotify 學生方案」'), findsOneWidget);
    await tester.tap(find.text('確認停用'));
    await tester.pumpAndSettle();
    expect(find.text('已停用'), findsOneWidget);
    expect(find.text('0 個啟用中'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('app startup processes a due automatic subscription', (
    tester,
  ) async {
    await database.customSelect('SELECT 1').get();
    final categories = await database.select(database.categories).get();
    final category = categories.singleWhere((item) => item.name == '日用品');
    await DriftSubscriptionRepository(database).createSubscription(
      SubscriptionInput(
        categoryId: category.id,
        name: '手機網路費',
        amount: 499,
        billingCycle: BillingCycle.monthly,
        startDate: DateTime(2026, 7, 22),
        nextBillingDate: DateTime(2026, 7, 22),
        autoCreateTransaction: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          subscriptionTodayProvider.overrideWithValue(DateTime(2026, 7, 22)),
        ],
        child: const AccountingApp(),
      ),
    );
    await tester.pumpAndSettle();

    final transactions = await database.select(database.transactions).get();
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, 499);
    expect(transactions.single.note, '手機網路費 自動扣款');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
